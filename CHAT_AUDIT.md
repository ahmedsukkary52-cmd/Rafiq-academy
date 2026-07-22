# Chat / Messaging Audit — رفيق أكاديمي

تاريخ الجرد: 2026-07-19  
النطاق: كل ما يتعلق بالشات/المحادثات تحت `lib/` (أسماء ملفات + كلمات Chat / Conversation /
Message)  
**لا تعديلات كود** — تقرير فحص فقط.

---

## 1) ملخص تنفيذي

| البند                    | الخلاصة                                                                                             |
|--------------------------|-----------------------------------------------------------------------------------------------------|
| Feature رئيسي            | `lib/features/chat/` — Clean Architecture كاملة (domain / data / presentation)                      |
| UI موصول فعلاً           | تاب **الرسائل** عند المعلم فقط (`TeacherMessagesTab` داخل `TeacherHomePage`)                        |
| Route الشات              | `/teacher/chat/:conversationId` فقط — محمي بـ `_isAllowedRoute` (مسارات `/teacher/*` للمعلم)        |
| Backend                  | **Firestore فقط** (`conversations` + subcollection `messages`) — **مفيش Firebase Storage** في الشات |
| أنواع الرسائل            | **نص فقط** (`text`) — أيقونة المايك في الـ UI ديكور بدون فعل                                        |
| الطالب                   | **ممنوع متعمداً** في `ChatPermissionPolicy` + مفيش route/UI طالب                                    |
| ولي الأمر / مشرف / إدارة | مسموح لهم في الـ **policy** جزئياً، لكن **مفيش UI/routes** لهم للشات                                |

---

## 2) فهرس الملفات المتعلقة بالشات

### 2.1 Feature: `lib/features/chat/`

| الملف                                             | الطبقة / النوع                     |
|---------------------------------------------------|------------------------------------|
| `domain/entities/chat_entities.dart`              | Entities                           |
| `domain/policies/chat_permission_policy.dart`     | Policy + `ConversationIdGenerator` |
| `domain/repositories/chat_repository.dart`        | Repository interface               |
| `domain/usecases/chat_usecases.dart`              | Use cases + Params                 |
| `data/models/chat_models.dart`                    | Firestore models                   |
| `data/datasources/chat_remote_datasource.dart`    | Remote datasource (Firestore)      |
| `data/repositories/chat_repository_impl.dart`     | Repository impl                    |
| `presentation/bloc/chat_conversations_bloc.dart`  | Bloc (قائمة محادثات)               |
| `presentation/bloc/chat_conversations_event.dart` | Events                             |
| `presentation/bloc/chat_conversations_state.dart` | State                              |
| `presentation/bloc/chat_room_bloc.dart`           | Bloc (غرفة محادثة)                 |
| `presentation/bloc/chat_room_event.dart`          | Events                             |
| `presentation/bloc/chat_room_state.dart`          | State                              |
| `presentation/pages/chat_conversations_page.dart` | UI صفحة قائمة محادثات              |
| `presentation/pages/chat_room.dart`               | UI غرفة المحادثة                   |

### 2.2 تكامل خارج الـ feature

| الملف                                                               | العلاقة بالشات                                                        |
|---------------------------------------------------------------------|-----------------------------------------------------------------------|
| `lib/features/teacher/presentation/pages/teacher_messages_tab.dart` | تاب رسائل المعلم (الدخول الفعلي للشات)                                |
| `lib/features/teacher/presentation/pages/teacher_home_page.dart`    | يضم `TeacherMessagesTab` في الـ bottom nav (index 3)                  |
| `lib/core/router/router_app.dart`                                   | `AppRoutes.teacherChat` + route `chat/:conversationId` تحت `/teacher` |
| `lib/core/constants/app_constants.dart`                             | `FirestoreCollections.conversations` / `messagesSubcollection`        |
| `lib/core/di/injection_container.config.dart`                       | تسجيل Chat datasource / repo / use cases / blocs                      |

### 2.3 ملفات تحمل كلمة Message لكنها **مش شات**

| الملف                                                                                  | ملاحظة                                                         |
|----------------------------------------------------------------------------------------|----------------------------------------------------------------|
| `homework_*` / `schedule_*` / `progress_report_*` / `review_schedule_*` / `audio_bloc` | حقول `*Message` لرسائل حالة BLoC (snackbar) — **ليست محادثات** |
| `notifications`                                                                        | إشعارات منفصلة، مش 1:1 chat                                    |

---

## 3) تفصيل كل ملف / صفحة / Bloc

### 3.1 Domain

#### `chat_entities.dart`

- **الغرض:** Entities — `ChatParticipantEntity`, `ConversationEntity`, `MessageEntity`
- **Firestore / Storage:** لا (domain خالص)
- **الوصول:** غير مربوط بـ route؛ يُستخدم من كل الطبقات
- **أنواع رسائل:** `MessageEntity` فيها `text` فقط (لا type / url / media)
- **الحالة:** مكتمل للنص

#### `chat_permission_policy.dart`

- **الغرض:** سياسة صلاحيات + توليد `conversationId` ثابت من uid الطرفين
- **Firestore / Storage:** لا
- **من مسموح يتكلم مع مين (حسب الكود):**

| الدور         | يقدر يتواصل مع                                           |
|---------------|----------------------------------------------------------|
| `teacher`     | `supervisor`, `admin`                                    |
| `parent`      | `supervisor`, `admin`                                    |
| `supervisor`  | `teacher`, `parent`, `admin`                             |
| `admin`       | `teacher`, `parent`, `supervisor`                        |
| **`student`** | **غير موجود في الـ map → `canChat` يرجع `false` دائماً** |

- **ملاحظة من التعليق في الكود:** مبنية على السبسيفيكيشن؛ دفاع في الـ use case مش بس الـ UI
- **الحالة:** مكتملة كسياسة للأدوار الأربعة أعلاه؛ الطالب مستبعد **عمداً**

#### `chat_repository.dart` + `chat_usecases.dart`

- **الغرض:** واجهة المستودع + use cases:
    - `WatchConversationsUseCase`
    - `WatchMessagesUseCase`
    - `GetOrCreateConversationUseCase` ← هنا يُطبَّق `ChatPermissionPolicy`
    - `SendMessageUseCase` (نص غير فاضي)
    - `MarkConversationAsReadUseCase`
- **Firestore / Storage:** عبر الـ repository فقط (Firestore)
- **الحالة:** مكتملة للتدفق النصي؛ بدء محادثة محمي بالـ policy

---

### 3.2 Data

#### `chat_models.dart`

- **الغرض:** Models من/إلى Firestore
- **Firestore:** نعم (mapping فقط)
- **Storage:** لا
- **شكل الرسالة في Firestore:** `senderId`, `text`, `sentAt`
- **شكل المحادثة:** `participantIds`, `participants[]`, `lastMessage`, `lastMessageAt`,
  `lastMessageSenderId`, `unreadCounts` (map per uid)
- **الحالة:** مكتمل للنص

#### `chat_remote_datasource.dart`

- **الغرض:** Datasource — قراءة/كتابة Firestore real-time
- **Firestore:** نعم فقط (`FirebaseFirestore`)
- **Storage:** **لا** — مفيش `FirebaseStorage` في الـ constructor ولا في أي method
- **Collections:**
    - `conversations`
    - `conversations/{id}/messages`
- **الحالة:** شغّالة لـ watch / send text / mark read / getOrCreate

#### `chat_repository_impl.dart`

- **الغرض:** Repository impl + فحص الشبكة
- **Firestore:** عبر datasource
- **Storage:** لا
- **الحالة:** مكتمل

---

### 3.3 Presentation — Blocs

#### `ChatConversationsBloc` (`@singleton`)

- **الغرض:** مراقبة قائمة محادثات المستخدم + بدء محادثة (`StartConversationEvent`)
- **Firestore:** عبر use cases
- **Storage:** لا
- **الوصول:** يُستدعى من `TeacherMessagesTab` و `ChatConversationsPage`
- **الحالة:** الـ watch شغّال؛ **بدء محادثة جديدة من الـ UI غير موصول** (`StartConversationEvent` مش
  بيتنادى من أي صفحة)

#### `ChatRoomBloc` (`@injectable` + factoryParam)

- **الغرض:** مراقبة رسائل محادثة + إرسال نص + mark as read عند الفتح
- **Firestore:** نعم
- **Storage:** لا
- **الوصول:** عبر `ChatRoomPage` فقط (route المعلم)
- **الحالة:** شغّالة للنص

---

### 3.4 Presentation — Pages / Tabs

#### `TeacherMessagesTab`

- **الغرض:** UI تاب «الرسائل» للمعلم (صندوق وارد)
- **Firestore:** عبر `ChatConversationsBloc`
- **Storage:** لا
- **الوصول:** معلم فقط — تاب داخل `TeacherHomePage` (bottom nav)
- **أنواع رسائل:** يعرض `lastMessage` كنص
- **نواقص UI واضحة:**
    - زرار `+` → `onPressed: () {}` فاضي
    - فلاتر (أولياء / مشرفون / إدارة) تغيّر الـ index فقط **بدون فلترة القائمة فعلياً**
    - حقل البحث UI فقط بدون منطق
- **الحالة:** **ناقصة** (عرض القائمة + الدخول للغرفة شغّال؛ إنشاء محادثة/فلترة/بحث مش مكتملين)

#### `ChatConversationsPage`

- **الغرض:** UI بديل لقائمة المحادثات (مشابه للتاب)
- **Firestore:** نعم عبر Bloc
- **Storage:** لا
- **الوصول:** **مفيش GoRoute مسجّل لها** → orphan تقريباً؛ التنقل منها hardcoded لـ
  `/teacher/chat/...`
- **الحالة:** **هيكل/مكرر** — مش مدخل المستخدم الحالي (المدخل = `TeacherMessagesTab`)

#### `ChatRoomPage` (`chat_room.dart`)

- **الغرض:** UI غرفة المحادثة (فقاعات + إدخال نص)
- **Firestore:** نعم
- **Storage:** لا
- **الوصول:** route `/teacher/chat/:conversationId` — المعلم فقط (`_isAllowedRoute`: path لازم يبدأ
  بـ `/teacher`)
- **أنواع رسائل:** عرض `message.text` فقط
- **أيقونة المايك** في `_MessageInputBar`: `Icon` ثابت **بدون `onTap`/تسجيل/رفع** → ديكور UI
- **«متصل الآن»** ثابت في الـ AppBar (مش حالة حقيقية)
- **الحالة:** **شغّالة بالكامل للنص**؛ وسائط غير موجودة

---

### 3.5 Router / Constants / DI

#### `router_app.dart`

- Route الشات الوحيد: تحت شجرة `/teacher` → `chat/:conversationId`
- حماية الدور: `_isAllowedRoute` → الطالب/ولي الأمر/المشرف/الإدارة **مش يقدروا يفتحوا**
  `/teacher/chat/...` حتى لو عرفوا الـ URL
- **مفيش** `/student/chat`, `/parent/chat`, `/supervisor/chat`, `/admin/chat`

#### `app_constants.dart`

- `FirestoreCollections.conversations = 'conversations'`
- `FirestoreCollections.messagesSubcollection = 'messages'`

#### DI

- `ChatRemoteDatasourceImpl(firestore)` فقط — بدون Storage
- `ChatConversationsBloc` singleton
- `ChatRoomBloc` factoryParam `(conversationId, currentUserId)`

---

## 4) هل فيه دعم لغير النص؟

| النوع | موجود في الـ model/datasource؟ | موجود في الـ UI؟ |
|-------|--------------------------------|------------------|
| نص    | نعم (`text`)                   | نعم              |
| صورة  | لا                             | لا               |
| صوت   | لا (أيقونة مايك ديكور)         | لا رفع/تشغيل     |
| ملف   | لا                             | لا               |

**الخلاصة:** الشات حالياً **نص فقط**. مفيش مسار رفع لـ Firebase Storage داخل feature الشات.

---

## 5) مين يوصل للشات؟ (Route + Policy)

```
                    ┌─────────────────────┐
                    │ ChatPermissionPolicy│
                    │ (من يكلم مين)        │
                    └──────────┬──────────┘
                               │
     student ✗                 │
     teacher → supervisor/admin│
     parent  → supervisor/admin│
     supervisor → teacher/parent/admin
     admin → teacher/parent/supervisor
                               │
                    ┌──────────▼──────────┐
                    │ UI + GoRouter       │
                    └──────────┬──────────┘
                               │
     teacher ✓ (Messages tab + /teacher/chat/:id)
     parent / supervisor / admin ✗ (مفيش screens/routes رغم السماح في policy)
     student ✗ (policy + مفيش UI)
```

---

## 6) سؤال محوري: الطالب ممنوع ليه؟

**الإجابة: ممنوع بقرار متعمد في الـ policy، مش بس «لسه متحدش الجزء بتاعه».**

الأدلة من الكود:

1. **`ChatPermissionPolicy`** لا تتضمن `AppRoles.student` في `_allowedPairs` أصلاً. أي محاولة
   `GetOrCreateConversation` بدور طالب →
   `ValidationFailure('غير مسموح بالتواصل بين هذين الحسابين')`.
2. التعليق أعلى الـ policy يصف قواعد التواصل بين معلم/ولي أمر/مشرف/إدارة — **بدون ذكر الطالب كطرف
   محادثة**.
3. بالإضافة لذلك: مفيش route طالب للشات، ومفيش تاب رسائل في `StudentHomePage` — ده غياب UI، لكنه *
   *متوافق** مع السياسة مش مناقض ليها.

يعني: حتى لو اتبنى UI طالب بكرة، لازم يتغيّر الـ policy أولاً (أو يُستثنى مسار معيّن) وإلا الـ use
case هيرفض.

> ملاحظة مقارنة: ولي الأمر/المشرف/الإدارة **مسموح لهم في الـ policy** لكن واجهتهم للشات **لسه
متبنيتش** — ده «نقص تنفيذ UI»، مش منع سياسة. الطالب مختلف: **منع سياسة + نقص UI**.

---

## 7) حالة الميزة إجمالاً

| الجزء                                   | الحالة                                    |
|-----------------------------------------|-------------------------------------------|
| نموذج البيانات + Firestore CRUD نصي     | شغّال                                     |
| Real-time watch للمحادثات/الرسائل       | شغّال                                     |
| غرفة المحادثة (إرسال/استقبال نص) للمعلم | شغّال                                     |
| تاب رسائل المعلم                        | شغّال جزئياً (عرض + فتح غرفة)             |
| إنشاء محادثة جديدة من UI                | ناقص (زرار فاضي / event غير مستخدم من UI) |
| فلترة/بحث في تاب الرسائل                | هيكل UI فقط                               |
| `ChatConversationsPage`                 | مكرر / غير مربوط بالـ router              |
| رسائل وسائط (صورة/صوت/ملف) + Storage    | غير موجود                                 |
| UI لولي الأمر / مشرف / إدارة            | غير موجود                                 |
| UI / صلاحية للطالب                      | ممنوع بالـ policy + غير موجود             |

**التصنيف العام:** Backend نصي + تجربة معلم أساسية **شغّالة**؛ باقي الأدوار والوسائط وبدء المحادثة *
*ناقصة**.

---

## 8) شكل بيانات Firestore (مرجع سريع)

### `conversations/{conversationId}`

```
participantIds: [uidA, uidB]
participants: [{ uid, name, role, profileImageUrl? }, ...]
lastMessage: string | null
lastMessageAt: Timestamp
lastMessageSenderId: string | null
unreadCounts: { [uid]: int }
```

`conversationId` = `sorted(uidA, uidB).join('_')`

### `conversations/{id}/messages/{messageId}`

```
senderId: string
text: string
sentAt: Timestamp
```

---

## 9) توصيات لاحقة (مرجع فقط — مش جزء من التنفيذ الحالي)

1. لو مطلوب شات طالب↔معلم: تحديث `ChatPermissionPolicy` + routes تحت `/student` وربط UI.
2. لو مطلوب إكمال الأدوار الأخرى: صفحات محادثات لـ parent/supervisor/admin بنفس الـ blocs الموجودة (
   الـ domain جاهز نسبياً).
3. تفعيل `StartConversationEvent` من زرار `+` مع اختيار مستلم حسب الـ policy.
4. لو مطلوب وسائط: توسيع `MessageEntity` + Storage path + UI — حالياً صفر أساس في الشات.
5. إما ربط `ChatConversationsPage` بالـ router أو حذف/دمجها مع `TeacherMessagesTab` لتجنب
   الازدواجية.

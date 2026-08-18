// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:cloud_firestore/cloud_firestore.dart' as _i974;
import 'package:cloud_functions/cloud_functions.dart' as _i809;
import 'package:firebase_auth/firebase_auth.dart' as _i59;
import 'package:firebase_storage/firebase_storage.dart' as _i457;
import 'package:flutter/material.dart' as _i409;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart'
    as _i161;
import 'package:rafiq_academy/core/di/di_module.dart' as _i126;
import 'package:rafiq_academy/core/network/network_info.dart' as _i696;
import 'package:rafiq_academy/features/admin/data/datasources/admin_remote_datasource.dart'
    as _i543;
import 'package:rafiq_academy/features/admin/data/datasources/admin_remote_datasource_impl.dart'
    as _i775;
import 'package:rafiq_academy/features/admin/data/repositories/admin_repository_impl.dart'
    as _i99;
import 'package:rafiq_academy/features/admin/domain/repositories/admin_repository.dart'
    as _i255;
import 'package:rafiq_academy/features/admin/domain/usecases/approve_new_student_usecase.dart'
    as _i928;
import 'package:rafiq_academy/features/admin/domain/usecases/get_academy_stats_usecase.dart'
    as _i488;
import 'package:rafiq_academy/features/admin/domain/usecases/get_all_teachers_usecase.dart'
    as _i975;
import 'package:rafiq_academy/features/admin/domain/usecases/get_complaints_usecase.dart'
    as _i899;
import 'package:rafiq_academy/features/admin/domain/usecases/get_financial_summary_usecase.dart'
    as _i369;
import 'package:rafiq_academy/features/admin/domain/usecases/get_teacher_activity_log_usecase.dart'
    as _i1063;
import 'package:rafiq_academy/features/admin/domain/usecases/respond_to_complaint_usecase.dart'
    as _i97;
import 'package:rafiq_academy/features/admin/domain/usecases/send_broadcast_notification_usecase.dart'
    as _i57;
import 'package:rafiq_academy/features/admin/domain/usecases/toggle_account_status_usecase.dart'
    as _i482;
import 'package:rafiq_academy/features/admin/domain/usecases/update_teacher_performance_usecase.dart'
    as _i413;
import 'package:rafiq_academy/features/admin/domain/usecases/update_teacher_quota_usecase.dart'
    as _i1014;
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_bloc.dart'
    as _i409;
import 'package:rafiq_academy/features/analytics/data/datasources/analytics_remote_datasource.dart'
    as _i797;
import 'package:rafiq_academy/features/analytics/data/datasources/analytics_remote_datasource_impl.dart'
    as _i704;
import 'package:rafiq_academy/features/analytics/data/repositories/analytics_repository_impl.dart'
    as _i646;
import 'package:rafiq_academy/features/analytics/domain/repositories/analytics_repository.dart'
    as _i656;
import 'package:rafiq_academy/features/analytics/domain/usecases/analytics_usecases.dart'
    as _i1010;
import 'package:rafiq_academy/features/analytics/presentation/bloc/analytics_bloc.dart'
    as _i999;
import 'package:rafiq_academy/features/audio_library/data/datasources/audio_library_remote_datasource.dart'
    as _i1052;
import 'package:rafiq_academy/features/audio_library/data/datasources/audio_library_remote_datasource_impl.dart'
    as _i694;
import 'package:rafiq_academy/features/audio_library/data/datasources/mp3quran_catalog_service.dart'
    as _i638;
import 'package:rafiq_academy/features/audio_library/data/repositories/audio_library_repository_impl.dart'
    as _i4;
import 'package:rafiq_academy/features/audio_library/data/services/audio_player_service.dart'
    as _i297;
import 'package:rafiq_academy/features/audio_library/domain/repositories/audio_library_repository.dart'
    as _i174;
import 'package:rafiq_academy/features/audio_library/domain/usecases/audio_usecases.dart'
    as _i30;
import 'package:rafiq_academy/features/audio_library/presentation/bloc/audio_bloc.dart'
    as _i407;
import 'package:rafiq_academy/features/auth/data/datasources/auth_remote_datasouce_impl.dart'
    as _i550;
import 'package:rafiq_academy/features/auth/data/datasources/auth_remote_datasource.dart'
    as _i483;
import 'package:rafiq_academy/features/auth/data/repositories/auth_repository_impl.dart'
    as _i127;
import 'package:rafiq_academy/features/auth/domain/repositories/auth_repository.dart'
    as _i605;
import 'package:rafiq_academy/features/auth/domain/usecases/get_current_user_usecase.dart'
    as _i788;
import 'package:rafiq_academy/features/auth/domain/usecases/login_with_email_usecase.dart'
    as _i339;
import 'package:rafiq_academy/features/auth/domain/usecases/logout_usecase.dart'
    as _i608;
import 'package:rafiq_academy/features/auth/domain/usecases/register_with_email_usecase.dart'
    as _i880;
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart'
    as _i18;
import 'package:rafiq_academy/features/awards/data/datasources/award_remote_datasource.dart'
    as _i444;
import 'package:rafiq_academy/features/awards/data/datasources/award_remote_datasource_impl.dart'
    as _i982;
import 'package:rafiq_academy/features/awards/data/repositories/awards_repository_impl.dart'
    as _i662;
import 'package:rafiq_academy/features/awards/data/services/certificate_pdf_generator.dart'
    as _i649;
import 'package:rafiq_academy/features/awards/domain/repositories/awards_repository.dart'
    as _i888;
import 'package:rafiq_academy/features/awards/domain/usecases/awards_usecases.dart'
    as _i186;
import 'package:rafiq_academy/features/awards/presentation/bloc/awards_bloc.dart'
    as _i285;
import 'package:rafiq_academy/features/calendar/data/datasources/calendar_remote_datasource.dart'
    as _i537;
import 'package:rafiq_academy/features/calendar/data/datasources/calendar_remote_datasource_impl.dart'
    as _i209;
import 'package:rafiq_academy/features/calendar/data/repositories/calendar_repository_impl.dart'
    as _i763;
import 'package:rafiq_academy/features/calendar/domain/repositories/calendar_repository.dart'
    as _i669;
import 'package:rafiq_academy/features/calendar/domain/usecases/calendar_usecases.dart'
    as _i429;
import 'package:rafiq_academy/features/calendar/presentation/bloc/calendar_bloc.dart'
    as _i919;
import 'package:rafiq_academy/features/chat/data/datasources/chat_remote_datasource.dart'
    as _i164;
import 'package:rafiq_academy/features/chat/data/repositories/chat_repository_impl.dart'
    as _i369;
import 'package:rafiq_academy/features/chat/domain/repositories/chat_repository.dart'
    as _i194;
import 'package:rafiq_academy/features/chat/domain/usecases/chat_usecases.dart'
    as _i337;
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_bloc.dart'
    as _i618;
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_room_bloc.dart'
    as _i467;
import 'package:rafiq_academy/features/content/data/datasources/content_library_remote_datasource.dart'
    as _i37;
import 'package:rafiq_academy/features/content/data/datasources/content_library_remote_datasource_impl.dart'
    as _i752;
import 'package:rafiq_academy/features/content/data/repositories/content_repository_impl.dart'
    as _i669;
import 'package:rafiq_academy/features/content/domain/repositories/content_library_repository.dart'
    as _i283;
import 'package:rafiq_academy/features/content/domain/usecases/content_usecases.dart'
    as _i89;
import 'package:rafiq_academy/features/content/presentation/bloc/content_bloc.dart'
    as _i542;
import 'package:rafiq_academy/features/halaqa_activity/data/datasources/halaqa_activity_remote_datasource.dart'
    as _i852;
import 'package:rafiq_academy/features/halaqa_activity/data/datasources/halaqa_activity_remote_datasource_impl.dart'
    as _i950;
import 'package:rafiq_academy/features/halaqa_activity/data/repositories/halaqa_activity_repository_impl.dart'
    as _i196;
import 'package:rafiq_academy/features/halaqa_activity/domain/repositories/halaqa_activity_repository.dart'
    as _i7;
import 'package:rafiq_academy/features/halaqa_activity/domain/usecases/halaqa_activity_usecases.dart'
    as _i900;
import 'package:rafiq_academy/features/homework/data/datasources/homework_remote_datasource.dart'
    as _i31;
import 'package:rafiq_academy/features/homework/data/datasources/homework_remote_datasource_impl.dart'
    as _i119;
import 'package:rafiq_academy/features/homework/data/repositories/homework_repository_impl.dart'
    as _i14;
import 'package:rafiq_academy/features/homework/domain/repositories/homework_repository.dart'
    as _i951;
import 'package:rafiq_academy/features/homework/domain/usecases/homework_usecases.dart'
    as _i81;
import 'package:rafiq_academy/features/homework/presentation/bloc/homework_bloc.dart'
    as _i421;
import 'package:rafiq_academy/features/notifications/data/datasources/notifications_remote_datasource.dart'
    as _i676;
import 'package:rafiq_academy/features/notifications/data/repositories/notifiaction_repository.dart'
    as _i579;
import 'package:rafiq_academy/features/notifications/data/sinks/in_app_academy_event_handler.dart'
    as _i815;
import 'package:rafiq_academy/features/notifications/domain/repositories/notifications_repository.dart'
    as _i587;
import 'package:rafiq_academy/features/notifications/domain/usecases/notification_usecase.dart'
    as _i152;
import 'package:rafiq_academy/features/notifications/presentation/bloc/notifications_bloc.dart'
    as _i164;
import 'package:rafiq_academy/features/parent/data/data_source/parent_remote_datasource.dart'
    as _i892;
import 'package:rafiq_academy/features/parent/data/data_source/parent_remote_datasource_impl.dart'
    as _i430;
import 'package:rafiq_academy/features/parent/data/observers/default_academy_event_observer_resolver.dart'
    as _i890;
import 'package:rafiq_academy/features/parent/data/repositories/parent_repository_impl.dart'
    as _i964;
import 'package:rafiq_academy/features/parent/domain/repositories/parent_repositories.dart'
    as _i493;
import 'package:rafiq_academy/features/parent/domain/usecases/get_absence_requests_usecase.dart'
    as _i1044;
import 'package:rafiq_academy/features/parent/domain/usecases/get_attendance_marks_usecase.dart'
    as _i1104;
import 'package:rafiq_academy/features/parent/domain/usecases/get_children_ids_usecase.dart'
    as _i379;
import 'package:rafiq_academy/features/parent/domain/usecases/get_halaqat_for_student_usecase.dart'
    as _i242;
import 'package:rafiq_academy/features/parent/domain/usecases/get_parent_household_usecase.dart'
    as _i1103;
import 'package:rafiq_academy/features/parent/domain/usecases/get_payments_usecase.dart'
    as _i817;
import 'package:rafiq_academy/features/parent/domain/usecases/get_wallet_usecase.dart'
    as _i1101;
import 'package:rafiq_academy/features/parent/domain/usecases/get_weekly_report_usecase.dart'
    as _i379;
import 'package:rafiq_academy/features/parent/domain/usecases/initiate_payment_usecase.dart'
    as _i693;
import 'package:rafiq_academy/features/parent/domain/usecases/pay_payment_from_wallet_usecase.dart'
    as _i1102;
import 'package:rafiq_academy/features/parent/domain/usecases/submit_absence_request_usecase.dart'
    as _i888;
import 'package:rafiq_academy/features/parent/presentation/bloc/parent_bloc.dart'
    as _i995;
import 'package:rafiq_academy/features/post/data/datasources/posts_remote_datasorce_impl.dart'
    as _i307;
import 'package:rafiq_academy/features/post/data/datasources/posts_remote_datasource.dart'
    as _i1073;
import 'package:rafiq_academy/features/post/data/repositories/post_repository_impl.dart'
    as _i251;
import 'package:rafiq_academy/features/post/domain/repositories/posts_repository.dart'
    as _i486;
import 'package:rafiq_academy/features/post/domain/usecases/posts_usecases.dart'
    as _i918;
import 'package:rafiq_academy/features/post/presentation/bloc/posts_bloc.dart'
    as _i532;
import 'package:rafiq_academy/features/progress_report/data/datasources/progress_report_remote_datasource.dart'
    as _i102;
import 'package:rafiq_academy/features/progress_report/data/datasources/progress_report_remote_datasource_impl.dart'
    as _i1061;
import 'package:rafiq_academy/features/progress_report/data/repositories/progress_report_repository_impl.dart'
    as _i1044;
import 'package:rafiq_academy/features/progress_report/domain/repositories/progress_report_repository.dart'
    as _i824;
import 'package:rafiq_academy/features/progress_report/domain/usecases/get_progress_report_usecase.dart'
    as _i235;
import 'package:rafiq_academy/features/progress_report/presentation/bloc/progress_report_bloc.dart'
    as _i251;
import 'package:rafiq_academy/features/review_schedule/data/datasources/review_schedule_remote_datasource.dart'
    as _i333;
import 'package:rafiq_academy/features/review_schedule/data/datasources/review_schedule_remote_datasource_impl.dart'
    as _i590;
import 'package:rafiq_academy/features/review_schedule/data/repositories/review_schedule_repository_impl.dart'
    as _i255;
import 'package:rafiq_academy/features/review_schedule/domain/repositories/review_schedule_repository.dart'
    as _i905;
import 'package:rafiq_academy/features/review_schedule/domain/usecases/get_review_month_usecase.dart'
    as _i173;
import 'package:rafiq_academy/features/review_schedule/presentation/bloc/review_schedule_bloc.dart'
    as _i232;
import 'package:rafiq_academy/features/schedule/data/datasources/schedule_remote_datasource.dart'
    as _i756;
import 'package:rafiq_academy/features/schedule/data/datasources/schedule_remote_datasource_impl.dart'
    as _i1027;
import 'package:rafiq_academy/features/schedule/data/repositories/schedule_repository_impl.dart'
    as _i268;
import 'package:rafiq_academy/features/schedule/domain/repositories/schedule_repository.dart'
    as _i552;
import 'package:rafiq_academy/features/schedule/domain/usecases/get_weekly_sessions_usecase.dart'
    as _i891;
import 'package:rafiq_academy/features/schedule/presentation/bloc/schedule_bloc.dart'
    as _i951;
import 'package:rafiq_academy/features/student/data/data_source/student_remote_datasource.dart'
    as _i536;
import 'package:rafiq_academy/features/student/data/data_source/student_remote_datasource_impl.dart'
    as _i53;
import 'package:rafiq_academy/features/student/data/repositories/student_repository_impl.dart'
    as _i633;
import 'package:rafiq_academy/features/student/domain/repositories/student_repository.dart'
    as _i724;
import 'package:rafiq_academy/features/student/domain/usecases/get_achievements_usecase.dart'
    as _i224;
import 'package:rafiq_academy/features/student/domain/usecases/get_latest_assignment_usecase.dart'
    as _i664;
import 'package:rafiq_academy/features/student/domain/usecases/get_monthly_review_schedule_usecase.dart'
    as _i230;
import 'package:rafiq_academy/features/student/domain/usecases/get_recitation_records_usecase.dart'
    as _i124;
import 'package:rafiq_academy/features/student/domain/usecases/get_student_halaqa_usecase.dart'
    as _i554;
import 'package:rafiq_academy/features/student/domain/usecases/get_student_profile_usecase.dart'
    as _i385;
import 'package:rafiq_academy/features/student/domain/usecases/update_avatar_selection_usecase.dart'
    as _i479;
import 'package:rafiq_academy/features/student/domain/usecases/watch_latest_assignment_usecase.dart'
    as _i914;
import 'package:rafiq_academy/features/student/presentation/bloc/student_bloc.dart'
    as _i303;
import 'package:rafiq_academy/features/student/presentation/pages/student_audio_library_page.dart'
    as _i519;
import 'package:rafiq_academy/features/supervisor/data/data_sources/supervisor_remote_datasource.dart'
    as _i65;
import 'package:rafiq_academy/features/supervisor/data/data_sources/supervisor_remote_datasource_impl.dart'
    as _i615;
import 'package:rafiq_academy/features/supervisor/data/repositories/supervisor_repository_impl.dart'
    as _i582;
import 'package:rafiq_academy/features/supervisor/domain/repositories/parent_repository.dart'
    as _i307;
import 'package:rafiq_academy/features/supervisor/domain/usecases/get_supervised_absence_requests_usecase.dart'
    as _i904;
import 'package:rafiq_academy/features/supervisor/domain/usecases/get_supervised_halaqat_usecase.dart'
    as _i704;
import 'package:rafiq_academy/features/supervisor/domain/usecases/get_supervisor_day_board_usecase.dart'
    as _i824;
import 'package:rafiq_academy/features/supervisor/domain/usecases/issue_achievement_usecase.dart'
    as _i13;
import 'package:rafiq_academy/features/supervisor/domain/usecases/register_new_student_usecase.dart'
    as _i499;
import 'package:rafiq_academy/features/supervisor/domain/usecases/submit_supervisor_report_usecase.dart'
    as _i910;
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_bloc.dart'
    as _i149;
import 'package:rafiq_academy/features/teacher/data/data_sources/teacher_remote_datasource.dart'
    as _i717;
import 'package:rafiq_academy/features/teacher/data/data_sources/teacher_remote_datasource_impl.dart'
    as _i88;
import 'package:rafiq_academy/features/teacher/data/repositories/teacher_repository_impl.dart'
    as _i63;
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart'
    as _i1050;
import 'package:rafiq_academy/features/teacher/domain/usecases/add_recitation_record_usecase.dart'
    as _i877;
import 'package:rafiq_academy/features/teacher/domain/usecases/get_halaqa_attendance_for_date_usecase.dart'
    as _i122;
import 'package:rafiq_academy/features/teacher/domain/usecases/get_halaqa_recitation_records_usecase.dart'
    as _i998;
import 'package:rafiq_academy/features/teacher/domain/usecases/get_halaqa_students_usecase.dart'
    as _i440;
import 'package:rafiq_academy/features/teacher/domain/usecases/get_pending_absence_requests_usecase.dart'
    as _i775;
import 'package:rafiq_academy/features/teacher/domain/usecases/get_teacher_halaqt_usecase.dart'
    as _i626;
import 'package:rafiq_academy/features/teacher/domain/usecases/get_teacher_home_feed_usecase.dart'
    as _i407;
import 'package:rafiq_academy/features/teacher/domain/usecases/get_today_agenda_usecase.dart'
    as _i271;
import 'package:rafiq_academy/features/teacher/domain/usecases/record_attendance_usecase.dart'
    as _i642;
import 'package:rafiq_academy/features/teacher/domain/usecases/review_absence_request_usecase.dart'
    as _i182;
import 'package:rafiq_academy/features/teacher/domain/usecases/save_day_attendance_usecase.dart'
    as _i343;
import 'package:rafiq_academy/features/teacher/domain/usecases/send_assignment_usecase.dart'
    as _i192;
import 'package:rafiq_academy/features/teacher/domain/usecases/update_recitation_review_usecase.dart'
    as _i1070;
import 'package:rafiq_academy/features/teacher/domain/usecases/upsert_teacher_evaluation_usecase.dart'
    as _i1064;
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_bloc.dart'
    as _i933;
import 'package:rafiq_academy/shared/domain/academy_event_observer_resolver.dart'
    as _i937;
import 'package:rafiq_academy/shared/domain/academy_event_sink.dart' as _i273;
import 'package:rafiq_academy/shared/domain/attendance_service.dart' as _i295;
import 'package:rafiq_academy/shared/domain/evaluation_service.dart' as _i81;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final diModule = _$DiModule();
    gh.factory<_i638.Mp3QuranCatalogService>(
      () => _i638.Mp3QuranCatalogService(),
    );
    gh.lazySingleton<_i59.FirebaseAuth>(() => diModule.firebaseAuth);
    gh.lazySingleton<_i974.FirebaseFirestore>(() => diModule.firebaseFirestore);
    gh.lazySingleton<_i457.FirebaseStorage>(() => diModule.firebaseStorage);
    gh.lazySingleton<_i809.FirebaseFunctions>(() => diModule.firebaseFunctions);
    gh.lazySingleton<_i161.InternetConnection>(
      () => diModule.internetConnection,
    );
    gh.lazySingleton<_i297.AudioPlayerService>(
      () => _i297.AudioPlayerService(),
    );
    gh.lazySingleton<_i649.CertificatePdfGenerator>(
      () => _i649.CertificatePdfGenerator(),
    );
    gh.lazySingleton<_i295.AttendanceService>(
      () => const _i295.AttendanceService(),
    );
    gh.lazySingleton<_i81.EvaluationService>(
      () => const _i81.EvaluationService(),
    );
    gh.lazySingleton<_i1052.AudioLibraryRemoteDatasource>(
      () => _i694.AudioLibraryRemoteDatasourceImpl(
        firestore: gh<_i974.FirebaseFirestore>(),
        mp3QuranCatalog: gh<_i638.Mp3QuranCatalogService>(),
      ),
    );
    gh.lazySingleton<_i174.AudioLibraryRepository>(
      () => _i4.AudioLibraryRepositoryImpl(
        remoteDatasource: gh<_i1052.AudioLibraryRemoteDatasource>(),
        firebaseAuth: gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i483.AuthRemoteDatasource>(
      () => _i550.AuthRemoteDatasourceImpl(
        firebaseAuth: gh<_i59.FirebaseAuth>(),
        firestore: gh<_i974.FirebaseFirestore>(),
      ),
    );
    gh.factory<_i519.StudentAudioLibraryPage>(
      () => _i519.StudentAudioLibraryPage(key: gh<_i409.Key>()),
    );
    gh.lazySingleton<_i892.ParentRemoteDatasource>(
      () => _i430.ParentRemoteDatasourceImpl(
        firestore: gh<_i974.FirebaseFirestore>(),
        functions: gh<_i809.FirebaseFunctions>(),
      ),
    );
    gh.lazySingleton<_i37.ContentLibraryRemoteDatasource>(
      () => _i752.ContentLibraryRemoteDatasourceImpl(
        firestore: gh<_i974.FirebaseFirestore>(),
        storage: gh<_i457.FirebaseStorage>(),
      ),
    );
    gh.lazySingleton<_i65.SupervisorRemoteDatasource>(
      () => _i615.SupervisorRemoteDatasourceImpl(
        firestore: gh<_i974.FirebaseFirestore>(),
      ),
    );
    gh.lazySingleton<_i676.NotificationsRemoteDatasource>(
      () => _i676.NotificationsRemoteDatasourceImpl(
        firestore: gh<_i974.FirebaseFirestore>(),
      ),
    );
    gh.lazySingleton<_i333.ReviewScheduleRemoteDatasource>(
      () => _i590.ReviewScheduleRemoteDatasourceImpl(
        gh<_i974.FirebaseFirestore>(),
      ),
    );
    gh.lazySingleton<_i696.NetworkInfo>(
      () => diModule.networkInfo(gh<_i161.InternetConnection>()),
    );
    gh.lazySingleton<_i1073.PostsRemoteDatasource>(
      () => _i307.PostsRemoteDatasourceImpl(
        firestore: gh<_i974.FirebaseFirestore>(),
        storage: gh<_i457.FirebaseStorage>(),
      ),
    );
    gh.lazySingleton<_i486.PostsRepository>(
      () => _i251.PostsRepositoryImpl(
        remoteDatasource: gh<_i1073.PostsRemoteDatasource>(),
        networkInfo: gh<_i696.NetworkInfo>(),
      ),
    );
    gh.lazySingleton<_i717.TeacherRemoteDatasource>(
      () => _i88.TeacherRemoteDatasourceImpl(
        firestore: gh<_i974.FirebaseFirestore>(),
      ),
    );
    gh.lazySingleton<_i905.ReviewScheduleRepository>(
      () => _i255.ReviewScheduleRepositoryImpl(
        gh<_i333.ReviewScheduleRemoteDatasource>(),
      ),
    );
    gh.lazySingleton<_i536.StudentRemoteDatasource>(
      () => _i53.StudentRemoteDatasourceImpl(
        firestore: gh<_i974.FirebaseFirestore>(),
      ),
    );
    gh.lazySingleton<_i543.AdminRemoteDatasource>(
      () => _i775.AdminRemoteDatasourceImpl(
        firestore: gh<_i974.FirebaseFirestore>(),
      ),
    );
    gh.lazySingleton<_i283.ContentLibraryRepository>(
      () => _i669.ContentLibraryRepositoryImpl(
        remoteDatasource: gh<_i37.ContentLibraryRemoteDatasource>(),
        networkInfo: gh<_i696.NetworkInfo>(),
      ),
    );
    gh.lazySingleton<_i164.ChatRemoteDatasource>(
      () => _i164.ChatRemoteDatasourceImpl(
        firestore: gh<_i974.FirebaseFirestore>(),
      ),
    );
    gh.lazySingleton<_i31.HomeworkRemoteDatasource>(
      () => _i119.HomeworkRemoteDatasourceImpl(
        gh<_i974.FirebaseFirestore>(),
        gh<_i457.FirebaseStorage>(),
      ),
    );
    gh.lazySingleton<_i444.AwardsRemoteDatasource>(
      () => _i982.AwardsRemoteDatasourceImpl(
        firestore: gh<_i974.FirebaseFirestore>(),
        storage: gh<_i457.FirebaseStorage>(),
      ),
    );
    gh.lazySingleton<_i852.HalaqaActivityRemoteDatasource>(
      () => _i950.HalaqaActivityRemoteDatasourceImpl(
        firestore: gh<_i974.FirebaseFirestore>(),
        storage: gh<_i457.FirebaseStorage>(),
      ),
    );
    gh.lazySingleton<_i756.ScheduleRemoteDatasource>(
      () => _i1027.ScheduleRemoteDatasourceImpl(gh<_i974.FirebaseFirestore>()),
    );
    gh.factory<_i173.GetReviewMonthUseCase>(
      () => _i173.GetReviewMonthUseCase(gh<_i905.ReviewScheduleRepository>()),
    );
    gh.lazySingleton<_i797.AnalyticsRemoteDatasource>(
      () => _i704.AnalyticsRemoteDatasourceImpl(
        firestore: gh<_i974.FirebaseFirestore>(),
      ),
    );
    gh.lazySingleton<_i102.ProgressReportRemoteDatasource>(
      () => _i1061.ProgressReportRemoteDatasourceImpl(
        gh<_i974.FirebaseFirestore>(),
      ),
    );
    gh.lazySingleton<_i537.CalendarRemoteDatasource>(
      () => _i209.CalendarRemoteDatasourceImpl(
        firestore: gh<_i974.FirebaseFirestore>(),
      ),
    );
    gh.lazySingleton<_i951.HomeworkRepository>(
      () => _i14.HomeworkRepositoryImpl(gh<_i31.HomeworkRemoteDatasource>()),
    );
    gh.lazySingleton<_i307.SupervisorRepository>(
      () => _i582.SupervisorRepositoryImpl(
        remoteDatasource: gh<_i65.SupervisorRemoteDatasource>(),
        networkInfo: gh<_i696.NetworkInfo>(),
      ),
    );
    gh.lazySingleton<_i255.AdminRepository>(
      () => _i99.AdminRepositoryImpl(
        remoteDatasource: gh<_i543.AdminRemoteDatasource>(),
        networkInfo: gh<_i696.NetworkInfo>(),
      ),
    );
    gh.factory<_i30.GetAllRecitersUseCase>(
      () => _i30.GetAllRecitersUseCase(gh<_i174.AudioLibraryRepository>()),
    );
    gh.factory<_i30.GetFavoriteRecitersUseCase>(
      () => _i30.GetFavoriteRecitersUseCase(gh<_i174.AudioLibraryRepository>()),
    );
    gh.factory<_i30.ToggleFollowReciterUseCase>(
      () => _i30.ToggleFollowReciterUseCase(gh<_i174.AudioLibraryRepository>()),
    );
    gh.factory<_i30.GetSurahAudiosUseCase>(
      () => _i30.GetSurahAudiosUseCase(gh<_i174.AudioLibraryRepository>()),
    );
    gh.factory<_i30.SaveListeningProgressUseCase>(
      () =>
          _i30.SaveListeningProgressUseCase(gh<_i174.AudioLibraryRepository>()),
    );
    gh.factory<_i30.GetListeningProgressUseCase>(
      () =>
          _i30.GetListeningProgressUseCase(gh<_i174.AudioLibraryRepository>()),
    );
    gh.factory<_i30.GetContinueListeningUseCase>(
      () =>
          _i30.GetContinueListeningUseCase(gh<_i174.AudioLibraryRepository>()),
    );
    gh.lazySingleton<_i194.ChatRepository>(
      () => _i369.ChatRepositoryImpl(
        remoteDatasource: gh<_i164.ChatRemoteDatasource>(),
        networkInfo: gh<_i696.NetworkInfo>(),
      ),
    );
    gh.lazySingleton<_i493.ParentRepository>(
      () => _i964.ParentRepositoryImpl(
        remoteDatasource: gh<_i892.ParentRemoteDatasource>(),
        networkInfo: gh<_i696.NetworkInfo>(),
      ),
    );
    gh.lazySingleton<_i605.AuthRepository>(
      () => _i127.AuthRepositoryImpl(
        remoteDatasource: gh<_i483.AuthRemoteDatasource>(),
        networkInfo: gh<_i696.NetworkInfo>(),
      ),
    );
    gh.lazySingleton<_i824.ProgressReportRepository>(
      () => _i1044.ProgressReportRepositoryImpl(
        gh<_i102.ProgressReportRemoteDatasource>(),
      ),
    );
    gh.factory<_i880.RegisterWithEmailUseCase>(
      () => _i880.RegisterWithEmailUseCase(gh<_i605.AuthRepository>()),
    );
    gh.lazySingleton<_i788.GetCurrentUserUseCase>(
      () => _i788.GetCurrentUserUseCase(gh<_i605.AuthRepository>()),
    );
    gh.lazySingleton<_i339.LoginWithEmailUseCase>(
      () => _i339.LoginWithEmailUseCase(gh<_i605.AuthRepository>()),
    );
    gh.lazySingleton<_i608.LogoutUseCase>(
      () => _i608.LogoutUseCase(gh<_i605.AuthRepository>()),
    );
    gh.singleton<_i18.AuthBloc>(
      () => _i18.AuthBloc(
        loginWithEmail: gh<_i339.LoginWithEmailUseCase>(),
        registerWithEmail: gh<_i880.RegisterWithEmailUseCase>(),
        logout: gh<_i608.LogoutUseCase>(),
        getCurrentUser: gh<_i788.GetCurrentUserUseCase>(),
      ),
    );
    gh.lazySingleton<_i669.CalendarRepository>(
      () => _i763.CalendarRepositoryImpl(
        remoteDatasource: gh<_i537.CalendarRemoteDatasource>(),
        networkInfo: gh<_i696.NetworkInfo>(),
      ),
    );
    gh.lazySingleton<_i724.StudentRepository>(
      () => _i633.StudentRepositoryImpl(
        remoteDatasource: gh<_i536.StudentRemoteDatasource>(),
        networkInfo: gh<_i696.NetworkInfo>(),
      ),
    );
    gh.factory<_i232.ReviewScheduleBloc>(
      () => _i232.ReviewScheduleBloc(gh<_i173.GetReviewMonthUseCase>()),
    );
    gh.lazySingleton<_i656.AnalyticsRepository>(
      () => _i646.AnalyticsRepositoryImpl(
        remoteDatasource: gh<_i797.AnalyticsRemoteDatasource>(),
        networkInfo: gh<_i696.NetworkInfo>(),
      ),
    );
    gh.lazySingleton<_i587.NotificationsRepository>(
      () => _i579.NotificationsRepositoryImpl(
        remoteDatasource: gh<_i676.NotificationsRemoteDatasource>(),
        networkInfo: gh<_i696.NetworkInfo>(),
      ),
    );
    gh.factory<_i235.GetProgressReportUseCase>(
      () =>
          _i235.GetProgressReportUseCase(gh<_i824.ProgressReportRepository>()),
    );
    gh.lazySingleton<_i918.WatchPostsUseCase>(
      () => _i918.WatchPostsUseCase(gh<_i486.PostsRepository>()),
    );
    gh.lazySingleton<_i918.WatchCommentsUseCase>(
      () => _i918.WatchCommentsUseCase(gh<_i486.PostsRepository>()),
    );
    gh.lazySingleton<_i918.CreatePostUseCase>(
      () => _i918.CreatePostUseCase(gh<_i486.PostsRepository>()),
    );
    gh.lazySingleton<_i918.ToggleLikeUseCase>(
      () => _i918.ToggleLikeUseCase(gh<_i486.PostsRepository>()),
    );
    gh.lazySingleton<_i918.AddCommentUseCase>(
      () => _i918.AddCommentUseCase(gh<_i486.PostsRepository>()),
    );
    gh.lazySingleton<_i918.TogglePinUseCase>(
      () => _i918.TogglePinUseCase(gh<_i486.PostsRepository>()),
    );
    gh.lazySingleton<_i918.DeletePostUseCase>(
      () => _i918.DeletePostUseCase(gh<_i486.PostsRepository>()),
    );
    gh.lazySingleton<_i89.GetFilesUseCase>(
      () => _i89.GetFilesUseCase(gh<_i283.ContentLibraryRepository>()),
    );
    gh.lazySingleton<_i89.UploadFileUseCase>(
      () => _i89.UploadFileUseCase(gh<_i283.ContentLibraryRepository>()),
    );
    gh.lazySingleton<_i89.DeleteFileUseCase>(
      () => _i89.DeleteFileUseCase(gh<_i283.ContentLibraryRepository>()),
    );
    gh.lazySingleton<_i928.ApproveNewStudentUseCase>(
      () => _i928.ApproveNewStudentUseCase(gh<_i255.AdminRepository>()),
    );
    gh.lazySingleton<_i488.GetAcademyStatsUseCase>(
      () => _i488.GetAcademyStatsUseCase(gh<_i255.AdminRepository>()),
    );
    gh.lazySingleton<_i975.GetAllTeachersUseCase>(
      () => _i975.GetAllTeachersUseCase(gh<_i255.AdminRepository>()),
    );
    gh.lazySingleton<_i899.GetComplaintsUseCase>(
      () => _i899.GetComplaintsUseCase(gh<_i255.AdminRepository>()),
    );
    gh.lazySingleton<_i369.GetFinancialSummaryUseCase>(
      () => _i369.GetFinancialSummaryUseCase(gh<_i255.AdminRepository>()),
    );
    gh.lazySingleton<_i1063.GetTeacherActivityLogUseCase>(
      () => _i1063.GetTeacherActivityLogUseCase(gh<_i255.AdminRepository>()),
    );
    gh.lazySingleton<_i97.RespondToComplaintUseCase>(
      () => _i97.RespondToComplaintUseCase(gh<_i255.AdminRepository>()),
    );
    gh.lazySingleton<_i57.SendBroadcastNotificationUseCase>(
      () => _i57.SendBroadcastNotificationUseCase(gh<_i255.AdminRepository>()),
    );
    gh.lazySingleton<_i482.ToggleAccountStatusUseCase>(
      () => _i482.ToggleAccountStatusUseCase(gh<_i255.AdminRepository>()),
    );
    gh.lazySingleton<_i413.UpdateTeacherPerformanceUseCase>(
      () => _i413.UpdateTeacherPerformanceUseCase(gh<_i255.AdminRepository>()),
    );
    gh.lazySingleton<_i1014.UpdateTeacherQuotaUseCase>(
      () => _i1014.UpdateTeacherQuotaUseCase(gh<_i255.AdminRepository>()),
    );
    gh.factory<_i407.AudioLibraryBloc>(
      () => _i407.AudioLibraryBloc(
        getAllReciters: gh<_i30.GetAllRecitersUseCase>(),
        getFavoriteReciters: gh<_i30.GetFavoriteRecitersUseCase>(),
        toggleFollowReciter: gh<_i30.ToggleFollowReciterUseCase>(),
        getSurahAudios: gh<_i30.GetSurahAudiosUseCase>(),
        getContinueListening: gh<_i30.GetContinueListeningUseCase>(),
        saveListeningProgress: gh<_i30.SaveListeningProgressUseCase>(),
        getListeningProgress: gh<_i30.GetListeningProgressUseCase>(),
        audioPlayerService: gh<_i297.AudioPlayerService>(),
        firebaseAuth: gh<_i59.FirebaseAuth>(),
      ),
    );
    gh.lazySingleton<_i904.GetSupervisedAbsenceRequestsUseCase>(
      () => _i904.GetSupervisedAbsenceRequestsUseCase(
        gh<_i307.SupervisorRepository>(),
      ),
    );
    gh.lazySingleton<_i704.GetSupervisedHalaqatUseCase>(
      () => _i704.GetSupervisedHalaqatUseCase(gh<_i307.SupervisorRepository>()),
    );
    gh.lazySingleton<_i13.IssueAchievementUseCase>(
      () => _i13.IssueAchievementUseCase(gh<_i307.SupervisorRepository>()),
    );
    gh.lazySingleton<_i499.RegisterNewStudentUseCase>(
      () => _i499.RegisterNewStudentUseCase(gh<_i307.SupervisorRepository>()),
    );
    gh.lazySingleton<_i910.SubmitSupervisorReportUseCase>(
      () =>
          _i910.SubmitSupervisorReportUseCase(gh<_i307.SupervisorRepository>()),
    );
    gh.lazySingleton<_i552.ScheduleRepository>(
      () => _i268.ScheduleRepositoryImpl(gh<_i756.ScheduleRemoteDatasource>()),
    );
    gh.lazySingleton<_i429.GetMonthEventsUseCase>(
      () => _i429.GetMonthEventsUseCase(gh<_i669.CalendarRepository>()),
    );
    gh.lazySingleton<_i429.AddCalendarEventUseCase>(
      () => _i429.AddCalendarEventUseCase(gh<_i669.CalendarRepository>()),
    );
    gh.lazySingleton<_i429.DeleteCalendarEventUseCase>(
      () => _i429.DeleteCalendarEventUseCase(gh<_i669.CalendarRepository>()),
    );
    gh.factory<_i81.GetLatestHomeworkUseCase>(
      () => _i81.GetLatestHomeworkUseCase(gh<_i951.HomeworkRepository>()),
    );
    gh.factory<_i81.WatchLatestHomeworkUseCase>(
      () => _i81.WatchLatestHomeworkUseCase(gh<_i951.HomeworkRepository>()),
    );
    gh.factory<_i81.ToggleHomeworkTaskUseCase>(
      () => _i81.ToggleHomeworkTaskUseCase(gh<_i951.HomeworkRepository>()),
    );
    gh.factory<_i81.CompleteHomeworkUseCase>(
      () => _i81.CompleteHomeworkUseCase(gh<_i951.HomeworkRepository>()),
    );
    gh.factory<_i81.SubmitHomeworkRecitationUseCase>(
      () =>
          _i81.SubmitHomeworkRecitationUseCase(gh<_i951.HomeworkRepository>()),
    );
    gh.lazySingleton<_i888.AwardsRepository>(
      () => _i662.AwardsRepositoryImpl(
        remoteDatasource: gh<_i444.AwardsRemoteDatasource>(),
        pdfGenerator: gh<_i649.CertificatePdfGenerator>(),
        networkInfo: gh<_i696.NetworkInfo>(),
      ),
    );
    gh.lazySingleton<_i1010.GetHalaqaAnalyticsUseCase>(
      () => _i1010.GetHalaqaAnalyticsUseCase(gh<_i656.AnalyticsRepository>()),
    );
    gh.lazySingleton<_i1010.GetAtRiskStudentsUseCase>(
      () => _i1010.GetAtRiskStudentsUseCase(gh<_i656.AnalyticsRepository>()),
    );
    gh.lazySingleton<_i1010.GetTopStudentsUseCase>(
      () => _i1010.GetTopStudentsUseCase(gh<_i656.AnalyticsRepository>()),
    );
    gh.lazySingleton<_i337.WatchConversationsUseCase>(
      () => _i337.WatchConversationsUseCase(gh<_i194.ChatRepository>()),
    );
    gh.lazySingleton<_i337.WatchMessagesUseCase>(
      () => _i337.WatchMessagesUseCase(gh<_i194.ChatRepository>()),
    );
    gh.lazySingleton<_i337.GetOrCreateConversationUseCase>(
      () => _i337.GetOrCreateConversationUseCase(gh<_i194.ChatRepository>()),
    );
    gh.lazySingleton<_i337.SendMessageUseCase>(
      () => _i337.SendMessageUseCase(gh<_i194.ChatRepository>()),
    );
    gh.lazySingleton<_i337.MarkConversationAsReadUseCase>(
      () => _i337.MarkConversationAsReadUseCase(gh<_i194.ChatRepository>()),
    );
    gh.lazySingleton<_i337.GetChatParticipantUseCase>(
      () => _i337.GetChatParticipantUseCase(gh<_i194.ChatRepository>()),
    );
    gh.factory<_i999.AnalyticsBloc>(
      () => _i999.AnalyticsBloc(
        getHalaqaAnalytics: gh<_i1010.GetHalaqaAnalyticsUseCase>(),
        getAtRiskStudents: gh<_i1010.GetAtRiskStudentsUseCase>(),
        getTopStudents: gh<_i1010.GetTopStudentsUseCase>(),
      ),
    );
    gh.singleton<_i409.AdminBloc>(
      () => _i409.AdminBloc(
        getAcademyStats: gh<_i488.GetAcademyStatsUseCase>(),
        getFinancialSummary: gh<_i369.GetFinancialSummaryUseCase>(),
        getComplaints: gh<_i899.GetComplaintsUseCase>(),
        approveNewStudent: gh<_i928.ApproveNewStudentUseCase>(),
        toggleAccountStatus: gh<_i482.ToggleAccountStatusUseCase>(),
        respondToComplaint: gh<_i97.RespondToComplaintUseCase>(),
        sendBroadcastNotification: gh<_i57.SendBroadcastNotificationUseCase>(),
        getAllTeachers: gh<_i975.GetAllTeachersUseCase>(),
        updateTeacherPerformance: gh<_i413.UpdateTeacherPerformanceUseCase>(),
        updateTeacherQuota: gh<_i1014.UpdateTeacherQuotaUseCase>(),
        getTeacherActivityLog: gh<_i1063.GetTeacherActivityLogUseCase>(),
      ),
    );
    gh.lazySingleton<_i1044.GetAbsenceRequestsUseCase>(
      () => _i1044.GetAbsenceRequestsUseCase(gh<_i493.ParentRepository>()),
    );
    gh.lazySingleton<_i379.GetChildrenIdsUseCase>(
      () => _i379.GetChildrenIdsUseCase(gh<_i493.ParentRepository>()),
    );
    gh.lazySingleton<_i242.GetHalaqatForStudentUseCase>(
      () => _i242.GetHalaqatForStudentUseCase(gh<_i493.ParentRepository>()),
    );
    gh.lazySingleton<_i817.GetPaymentsUseCase>(
      () => _i817.GetPaymentsUseCase(gh<_i493.ParentRepository>()),
    );
    gh.lazySingleton<_i1101.GetWalletUseCase>(
      () => _i1101.GetWalletUseCase(gh<_i493.ParentRepository>()),
    );
    gh.lazySingleton<_i1102.PayPaymentFromWalletUseCase>(
      () => _i1102.PayPaymentFromWalletUseCase(gh<_i493.ParentRepository>()),
    );
    gh.lazySingleton<_i1103.GetParentHouseholdUseCase>(
      () => _i1103.GetParentHouseholdUseCase(gh<_i493.ParentRepository>()),
    );
    gh.lazySingleton<_i1104.GetAttendanceMarksUseCase>(
      () => _i1104.GetAttendanceMarksUseCase(gh<_i493.ParentRepository>()),
    );
    gh.lazySingleton<_i379.GetWeeklyReportUseCase>(
      () => _i379.GetWeeklyReportUseCase(gh<_i493.ParentRepository>()),
    );
    gh.lazySingleton<_i693.InitiatePaymentUseCase>(
      () => _i693.InitiatePaymentUseCase(gh<_i493.ParentRepository>()),
    );
    gh.lazySingleton<_i888.SubmitAbsenceRequestUseCase>(
      () => _i888.SubmitAbsenceRequestUseCase(gh<_i493.ParentRepository>()),
    );
    gh.lazySingleton<_i937.AcademyEventObserverResolver>(
      () => _i890.DefaultAcademyEventObserverResolver(
        parentRepository: gh<_i493.ParentRepository>(),
      ),
    );
    gh.lazySingleton<_i224.GetAchievementsUseCase>(
      () => _i224.GetAchievementsUseCase(gh<_i724.StudentRepository>()),
    );
    gh.lazySingleton<_i664.GetLatestAssignmentUseCase>(
      () => _i664.GetLatestAssignmentUseCase(gh<_i724.StudentRepository>()),
    );
    gh.lazySingleton<_i230.GetMonthlyReviewScheduleUseCase>(
      () =>
          _i230.GetMonthlyReviewScheduleUseCase(gh<_i724.StudentRepository>()),
    );
    gh.lazySingleton<_i124.GetRecitationRecordsUseCase>(
      () => _i124.GetRecitationRecordsUseCase(gh<_i724.StudentRepository>()),
    );
    gh.lazySingleton<_i554.GetStudentHalaqaUseCase>(
      () => _i554.GetStudentHalaqaUseCase(gh<_i724.StudentRepository>()),
    );
    gh.lazySingleton<_i385.GetStudentProfileUseCase>(
      () => _i385.GetStudentProfileUseCase(gh<_i724.StudentRepository>()),
    );
    gh.lazySingleton<_i479.UpdateAvatarSelectionUseCase>(
      () => _i479.UpdateAvatarSelectionUseCase(gh<_i724.StudentRepository>()),
    );
    gh.lazySingleton<_i914.WatchLatestAssignmentUseCase>(
      () => _i914.WatchLatestAssignmentUseCase(gh<_i724.StudentRepository>()),
    );
    gh.factory<_i542.ContentLibraryBloc>(
      () => _i542.ContentLibraryBloc(
        getFiles: gh<_i89.GetFilesUseCase>(),
        uploadFile: gh<_i89.UploadFileUseCase>(),
        deleteFile: gh<_i89.DeleteFileUseCase>(),
      ),
    );
    gh.singleton<_i618.ChatConversationsBloc>(
      () => _i618.ChatConversationsBloc(
        watchConversations: gh<_i337.WatchConversationsUseCase>(),
        getOrCreateConversation: gh<_i337.GetOrCreateConversationUseCase>(),
      ),
    );
    gh.factory<_i421.HomeworkBloc>(
      () => _i421.HomeworkBloc(
        watchLatestHomework: gh<_i81.WatchLatestHomeworkUseCase>(),
        toggleHomeworkTask: gh<_i81.ToggleHomeworkTaskUseCase>(),
        completeHomework: gh<_i81.CompleteHomeworkUseCase>(),
        submitHomeworkRecitation: gh<_i81.SubmitHomeworkRecitationUseCase>(),
      ),
    );
    gh.lazySingleton<_i152.WatchNotificationsUseCase>(
      () =>
          _i152.WatchNotificationsUseCase(gh<_i587.NotificationsRepository>()),
    );
    gh.lazySingleton<_i152.MarkNotificationAsReadUseCase>(
      () => _i152.MarkNotificationAsReadUseCase(
        gh<_i587.NotificationsRepository>(),
      ),
    );
    gh.lazySingleton<_i152.MarkAllNotificationsAsReadUseCase>(
      () => _i152.MarkAllNotificationsAsReadUseCase(
        gh<_i587.NotificationsRepository>(),
      ),
    );
    gh.lazySingleton<_i186.GetAwardsStatsUseCase>(
      () => _i186.GetAwardsStatsUseCase(gh<_i888.AwardsRepository>()),
    );
    gh.lazySingleton<_i186.GetGrantedAwardsUseCase>(
      () => _i186.GetGrantedAwardsUseCase(gh<_i888.AwardsRepository>()),
    );
    gh.lazySingleton<_i186.GrantAwardUseCase>(
      () => _i186.GrantAwardUseCase(gh<_i888.AwardsRepository>()),
    );
    gh.lazySingleton<_i186.GenerateCertificatePdfUseCase>(
      () => _i186.GenerateCertificatePdfUseCase(gh<_i888.AwardsRepository>()),
    );
    gh.factoryParam<_i467.ChatRoomBloc, String, String>(
      (conversationId, currentUserId) => _i467.ChatRoomBloc(
        gh<_i337.WatchMessagesUseCase>(),
        gh<_i337.SendMessageUseCase>(),
        gh<_i337.MarkConversationAsReadUseCase>(),
        conversationId,
        currentUserId,
      ),
    );
    gh.factory<_i891.GetWeeklySessionsUseCase>(
      () => _i891.GetWeeklySessionsUseCase(gh<_i552.ScheduleRepository>()),
    );
    gh.factory<_i919.CalendarBloc>(
      () => _i919.CalendarBloc(
        getMonthEvents: gh<_i429.GetMonthEventsUseCase>(),
        addCalendarEvent: gh<_i429.AddCalendarEventUseCase>(),
        deleteCalendarEvent: gh<_i429.DeleteCalendarEventUseCase>(),
      ),
    );
    gh.singleton<_i303.StudentBloc>(
      () => _i303.StudentBloc(
        getStudentProfile: gh<_i385.GetStudentProfileUseCase>(),
        getMonthlyReviewSchedule: gh<_i230.GetMonthlyReviewScheduleUseCase>(),
        getRecitationRecords: gh<_i124.GetRecitationRecordsUseCase>(),
        getAchievements: gh<_i224.GetAchievementsUseCase>(),
        getStudentHalaqa: gh<_i554.GetStudentHalaqaUseCase>(),
        watchLatestAssignment: gh<_i914.WatchLatestAssignmentUseCase>(),
        updateAvatarSelection: gh<_i479.UpdateAvatarSelectionUseCase>(),
      ),
    );
    gh.singleton<_i532.PostsBloc>(
      () => _i532.PostsBloc(
        watchPosts: gh<_i918.WatchPostsUseCase>(),
        watchComments: gh<_i918.WatchCommentsUseCase>(),
        createPost: gh<_i918.CreatePostUseCase>(),
        toggleLike: gh<_i918.ToggleLikeUseCase>(),
        addComment: gh<_i918.AddCommentUseCase>(),
        togglePin: gh<_i918.TogglePinUseCase>(),
        deletePost: gh<_i918.DeletePostUseCase>(),
      ),
    );
    gh.factory<_i285.AwardsBloc>(
      () => _i285.AwardsBloc(
        getAwardsStats: gh<_i186.GetAwardsStatsUseCase>(),
        getGrantedAwards: gh<_i186.GetGrantedAwardsUseCase>(),
        grantAward: gh<_i186.GrantAwardUseCase>(),
        generateCertificatePdf: gh<_i186.GenerateCertificatePdfUseCase>(),
      ),
    );
    gh.singleton<_i995.ParentBloc>(
      () => _i995.ParentBloc(
        getChildrenIds: gh<_i379.GetChildrenIdsUseCase>(),
        getWeeklyReport: gh<_i379.GetWeeklyReportUseCase>(),
        getPayments: gh<_i817.GetPaymentsUseCase>(),
        getAbsenceRequests: gh<_i1044.GetAbsenceRequestsUseCase>(),
        getHalaqatForStudent: gh<_i242.GetHalaqatForStudentUseCase>(),
        submitAbsenceRequest: gh<_i888.SubmitAbsenceRequestUseCase>(),
        initiatePayment: gh<_i693.InitiatePaymentUseCase>(),
        getHousehold: gh<_i1103.GetParentHouseholdUseCase>(),
        getWallet: gh<_i1101.GetWalletUseCase>(),
        payFromWallet: gh<_i1102.PayPaymentFromWalletUseCase>(),
      ),
    );
    gh.singleton<_i164.NotificationsBloc>(
      () => _i164.NotificationsBloc(
        watchNotifications: gh<_i152.WatchNotificationsUseCase>(),
        markNotificationAsRead: gh<_i152.MarkNotificationAsReadUseCase>(),
        markAllNotificationsAsRead:
            gh<_i152.MarkAllNotificationsAsReadUseCase>(),
      ),
    );
    gh.factory<_i251.ProgressReportBloc>(
      () => _i251.ProgressReportBloc(
        getProgressReport: gh<_i235.GetProgressReportUseCase>(),
        getStudentProfile: gh<_i385.GetStudentProfileUseCase>(),
      ),
    );
    gh.lazySingleton<_i815.InAppAcademyEventHandler>(
      () => _i815.InAppAcademyEventHandler(
        observerResolver: gh<_i937.AcademyEventObserverResolver>(),
        notificationsDatasource: gh<_i676.NotificationsRemoteDatasource>(),
        firestore: gh<_i974.FirebaseFirestore>(),
      ),
    );
    gh.factory<_i951.ScheduleBloc>(
      () => _i951.ScheduleBloc(gh<_i891.GetWeeklySessionsUseCase>()),
    );
    gh.lazySingleton<_i273.AcademyEventSink>(
      () => diModule.academyEventSink(gh<_i815.InAppAcademyEventHandler>()),
    );
    gh.lazySingleton<_i7.HalaqaActivityRepository>(
      () => _i196.HalaqaActivityRepositoryImpl(
        remoteDatasource: gh<_i852.HalaqaActivityRemoteDatasource>(),
        networkInfo: gh<_i696.NetworkInfo>(),
        eventSink: gh<_i273.AcademyEventSink>(),
        postsRepository: gh<_i486.PostsRepository>(),
      ),
    );
    gh.lazySingleton<_i900.PublishHalaqaActivityUseCase>(
      () => _i900.PublishHalaqaActivityUseCase(
        gh<_i7.HalaqaActivityRepository>(),
      ),
    );
    gh.lazySingleton<_i900.ListHalaqaActivitiesUseCase>(
      () =>
          _i900.ListHalaqaActivitiesUseCase(gh<_i7.HalaqaActivityRepository>()),
    );
    gh.lazySingleton<_i900.GetHalaqaActivityUseCase>(
      () => _i900.GetHalaqaActivityUseCase(gh<_i7.HalaqaActivityRepository>()),
    );
    gh.lazySingleton<_i900.SubmitHalaqaActivityResponseUseCase>(
      () => _i900.SubmitHalaqaActivityResponseUseCase(
        gh<_i7.HalaqaActivityRepository>(),
      ),
    );
    gh.lazySingleton<_i1050.TeacherRepository>(
      () => _i63.TeacherRepositoryImpl(
        remoteDatasource: gh<_i717.TeacherRemoteDatasource>(),
        networkInfo: gh<_i696.NetworkInfo>(),
        eventSink: gh<_i273.AcademyEventSink>(),
      ),
    );
    gh.lazySingleton<_i824.GetSupervisorDayBoardUseCase>(
      () => _i824.GetSupervisorDayBoardUseCase(
        teacherRepository: gh<_i1050.TeacherRepository>(),
        supervisorRepository: gh<_i307.SupervisorRepository>(),
      ),
    );
    gh.lazySingleton<_i407.GetTeacherHomeFeedUseCase>(
      () => _i407.GetTeacherHomeFeedUseCase(
        teacherRepository: gh<_i1050.TeacherRepository>(),
        awardsRepository: gh<_i888.AwardsRepository>(),
      ),
    );
    gh.lazySingleton<_i877.AddRecitationRecordUseCase>(
      () => _i877.AddRecitationRecordUseCase(gh<_i1050.TeacherRepository>()),
    );
    gh.lazySingleton<_i122.GetHalaqaAttendanceForDateUseCase>(
      () => _i122.GetHalaqaAttendanceForDateUseCase(
        gh<_i1050.TeacherRepository>(),
      ),
    );
    gh.lazySingleton<_i998.GetHalaqaRecitationRecordsUseCase>(
      () => _i998.GetHalaqaRecitationRecordsUseCase(
        gh<_i1050.TeacherRepository>(),
      ),
    );
    gh.lazySingleton<_i440.GetHalaqaStudentsUseCase>(
      () => _i440.GetHalaqaStudentsUseCase(gh<_i1050.TeacherRepository>()),
    );
    gh.lazySingleton<_i775.GetPendingAbsenceRequestsUseCase>(
      () => _i775.GetPendingAbsenceRequestsUseCase(
        gh<_i1050.TeacherRepository>(),
      ),
    );
    gh.lazySingleton<_i626.GetTeacherHalaqatUseCase>(
      () => _i626.GetTeacherHalaqatUseCase(gh<_i1050.TeacherRepository>()),
    );
    gh.lazySingleton<_i271.GetTodayAgendaUseCase>(
      () => _i271.GetTodayAgendaUseCase(gh<_i1050.TeacherRepository>()),
    );
    gh.lazySingleton<_i642.RecordAttendanceUseCase>(
      () => _i642.RecordAttendanceUseCase(gh<_i1050.TeacherRepository>()),
    );
    gh.lazySingleton<_i182.ReviewAbsenceRequestUseCase>(
      () => _i182.ReviewAbsenceRequestUseCase(gh<_i1050.TeacherRepository>()),
    );
    gh.lazySingleton<_i343.SaveDayAttendanceUseCase>(
      () => _i343.SaveDayAttendanceUseCase(gh<_i1050.TeacherRepository>()),
    );
    gh.lazySingleton<_i192.SendAssignmentUseCase>(
      () => _i192.SendAssignmentUseCase(gh<_i1050.TeacherRepository>()),
    );
    gh.lazySingleton<_i1070.UpdateRecitationReviewUseCase>(
      () =>
          _i1070.UpdateRecitationReviewUseCase(gh<_i1050.TeacherRepository>()),
    );
    gh.lazySingleton<_i1064.UpsertTeacherEvaluationUseCase>(
      () => _i1064.UpsertTeacherEvaluationUseCase(
        gh<_i1050.TeacherRepository>(),
        gh<_i81.EvaluationService>(),
      ),
    );
    gh.singleton<_i149.SupervisorBloc>(
      () => _i149.SupervisorBloc(
        getSupervisedHalaqat: gh<_i704.GetSupervisedHalaqatUseCase>(),
        getSupervisorDayBoard: gh<_i824.GetSupervisorDayBoardUseCase>(),
        getSupervisedAbsenceRequests:
            gh<_i904.GetSupervisedAbsenceRequestsUseCase>(),
        issueAchievement: gh<_i13.IssueAchievementUseCase>(),
        submitSupervisorReport: gh<_i910.SubmitSupervisorReportUseCase>(),
        registerNewStudent: gh<_i499.RegisterNewStudentUseCase>(),
      ),
    );
    gh.singleton<_i933.TeacherBloc>(
      () => _i933.TeacherBloc(
        getTeacherHalaqat: gh<_i626.GetTeacherHalaqatUseCase>(),
        getHalaqaStudents: gh<_i440.GetHalaqaStudentsUseCase>(),
        getHalaqaRecitationRecords:
            gh<_i998.GetHalaqaRecitationRecordsUseCase>(),
        getHalaqaAttendanceForDate:
            gh<_i122.GetHalaqaAttendanceForDateUseCase>(),
        saveDayAttendance: gh<_i343.SaveDayAttendanceUseCase>(),
        addRecitationRecord: gh<_i877.AddRecitationRecordUseCase>(),
        upsertTeacherEvaluation: gh<_i1064.UpsertTeacherEvaluationUseCase>(),
        updateRecitationReview: gh<_i1070.UpdateRecitationReviewUseCase>(),
        sendAssignment: gh<_i192.SendAssignmentUseCase>(),
        getTeacherHomeFeed: gh<_i407.GetTeacherHomeFeedUseCase>(),
        getPendingAbsenceRequests: gh<_i775.GetPendingAbsenceRequestsUseCase>(),
        reviewAbsenceRequest: gh<_i182.ReviewAbsenceRequestUseCase>(),
      ),
    );
    return this;
  }
}

class _$DiModule extends _i126.DiModule {}

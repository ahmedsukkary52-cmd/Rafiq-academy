/// Arabic label for a payment `status` (paid / overdue / due).
String paymentStatusLabel(String status) => switch (status) {
  'paid' => 'مدفوع',
  'overdue' => 'متأخر',
  _ => 'مستحق',
};

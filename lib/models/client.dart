class Client {
  final String phone;
  final String name;
  final int? discount; // null = без скидки

  Client({
    required this.phone,
    required this.name,
    this.discount,
  });

  factory Client.empty() => Client(phone: '', name: 'Гость', discount: null);
}

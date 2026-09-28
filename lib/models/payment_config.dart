class PaymentConfig {
  final String id;
  final String idEmpresa;
  final String pasarela; // 'manual', 'stripe', 'mercadopago'
  final String? publicKey;
  final String? secretKeyEncrypted;
  final String? stripeAccountId;
  final String? openaiApiKey;
  final String? whatsappApiKey;
  final String? mercadopagoAccessToken;
  final String? stripeSecretKey;
  final String moneda;
  final double montoDefault;
  final String? instruccionesTransferencia;

  PaymentConfig({
    required this.id,
    required this.idEmpresa,
    this.pasarela = 'manual',
    this.publicKey,
    this.secretKeyEncrypted,
    this.stripeAccountId,
    this.openaiApiKey,
    this.whatsappApiKey,
    this.mercadopagoAccessToken,
    this.stripeSecretKey,
    this.moneda = 'MXN',
    this.montoDefault = 499.0,
    this.instruccionesTransferencia,
  });

  factory PaymentConfig.fromJson(Map<String, dynamic> json) {
    return PaymentConfig(
      id: json['id']?.toString() ?? '',
      idEmpresa: json['IDEmpresa']?.toString() ?? '',
      pasarela: json['pasarela']?.toString() ?? 'manual',
      publicKey: json['public_key']?.toString(),
      secretKeyEncrypted: json['secret_key_encrypted']?.toString(),
      stripeAccountId: json['stripe_account_id']?.toString(),
      openaiApiKey: json['openai_api_key']?.toString(),
      whatsappApiKey: json['whatsapp_api_key']?.toString(),
      mercadopagoAccessToken: json['mercadopago_access_token']?.toString(),
      stripeSecretKey: json['stripe_secret_key']?.toString(),
      moneda: json['moneda']?.toString() ?? 'MXN',
      montoDefault: (json['monto_default'] as num?)?.toDouble() ?? 499.0,
      instruccionesTransferencia: json['instrucciones_transferencia']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'IDEmpresa': idEmpresa,
      'pasarela': pasarela,
      'public_key': publicKey,
      'secret_key_encrypted': secretKeyEncrypted,
      'stripe_account_id': stripeAccountId,
      'openai_api_key': openaiApiKey,
      'whatsapp_api_key': whatsappApiKey,
      'mercadopago_access_token': mercadopagoAccessToken,
      'stripe_secret_key': stripeSecretKey,
      'moneda': moneda,
      'monto_default': montoDefault,
      'instrucciones_transferencia': instruccionesTransferencia,
    };
  }
}

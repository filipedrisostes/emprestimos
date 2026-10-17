import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transacao.dart';
import '../currency_input_formatter.dart';
import '../services/partial_payment_service.dart';

class PartialPaymentInput {
  final double amount;
  final double? total;
  final int? installments;
  const PartialPaymentInput(this.amount, this.total, this.installments);
}

class PartialPaymentDialog extends StatefulWidget {
  final Transacao transaction;
  const PartialPaymentDialog({super.key, required this.transaction});
  @override
  State<PartialPaymentDialog> createState() => _PartialPaymentDialogState();
}

class _PartialPaymentDialogState extends State<PartialPaymentDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _total = TextEditingController();
  final _count = TextEditingController();
  bool _split = false;
  double _value(String text) =>
      (double.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0) / 100;
  String? _validMoney(String? text) {
    try {
      PartialPaymentService.cents(_value(text ?? ''));
      return null;
    } catch (_) {
      return 'Informe um valor positivo válido';
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _total.dispose();
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Pagamento parcial'),
        content: SingleChildScrollView(
            child: Form(
                key: _form,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                      'Saldo ${widget.transaction.parcelamento ? 'da parcela' : 'de juros'}: ${NumberFormat.currency(locale: 'pt_BR', symbol: r'R$').format(widget.transaction.saldo)}'),
                  TextFormField(
                      key: const Key('partial-amount'),
                      controller: _amount,
                      decoration:
                          const InputDecoration(labelText: 'Valor pago'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      validator: (text) =>
                          _validMoney(text) ??
                          (!_split &&
                                  _value(text ?? '') > widget.transaction.saldo
                              ? 'O pagamento supera o saldo'
                              : null)),
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Parcelar'),
                      value: _split,
                      onChanged: (value) =>
                          setState(() => _split = value ?? false)),
                  if (_split) ...[
                    TextFormField(
                        key: const Key('partial-total'),
                        controller: _total,
                        decoration: const InputDecoration(
                            labelText: 'Total para quitação',
                            helperText: 'Saldo restante, após o valor pago',
                            helperMaxLines: 2),
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyInputFormatter()],
                        validator: _validMoney),
                    TextFormField(
                        key: const Key('partial-count'),
                        controller: _count,
                        decoration: const InputDecoration(
                            labelText: 'Quantidade de parcelas'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (text) {
                          final n = int.tryParse(text ?? '') ?? 0;
                          return n < 1 ||
                                  n > 600 ||
                                  n > (_value(_total.text) * 100).round()
                              ? 'De 1 a 600 parcelas, mínimo R\$ 0,01 cada'
                              : null;
                        }),
                    const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                            'O acordo substituirá as cobranças em aberto deste empréstimo. Parcelas mensais sem juros adicionais; primeira parcela um mês após o pagamento.')),
                  ] else
                    Text(widget.transaction.parcelamento
                        ? 'Abater do saldo desta parcela do acordo.'
                        : 'Abater dos juros desta cobrança, mantendo o capital emprestado.'),
                ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate())
                  Navigator.pop(
                      context,
                      PartialPaymentInput(
                          _value(_amount.text),
                          _split ? _value(_total.text) : null,
                          _split ? int.parse(_count.text) : null));
              },
              child: const Text('Salvar pagamento'))
        ],
      );
}

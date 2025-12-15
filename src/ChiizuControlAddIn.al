controladdin "ChiizuPayments"
{
    Scripts = 'scripts/chiizu-connect.js';
    //StartupScript = 'scripts/startup.js';
    RequestedHeight = 500;
    RequestedWidth = 800;
    HorizontalStretch = true;
    VerticalStretch = true;

    event OnPaymentSuccess(paymentJson: Text);
    event OnPaymentError(errorJson: Text);

    procedure SetInvoiceData(invoiceNo: Code[20]; amount: Decimal);
}

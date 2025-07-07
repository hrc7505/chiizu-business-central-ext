controladdin InvoicessControlAddIn
{
    Scripts = 'src/views/common/base.js', 'src/views/invoices/invoices.js';
    StartupScript = 'src/views/invoices/invoices.js';
    StyleSheets = 'src/views/invoices/invoices.css';

    RequestedHeight = 400;
    MinimumHeight = 200;
    VerticalStretch = true;
    HorizontalStretch = true;

    procedure DisplayList(title: Text; jsonData: Text);
    procedure appendData(jsonData: Text);
    event OnJsReady();
    event loadMore();

}

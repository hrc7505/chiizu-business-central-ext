controladdin CustomersControlAddIn
{
    Scripts = 'src/views/common/base.js', 'src/views/customers/customers.js';
    StartupScript = 'src/views/customers/customers.js';
    StyleSheets = 'src/views/customers/customers.css';

    RequestedHeight = 400;
    MinimumHeight = 200;
    VerticalStretch = true;
    HorizontalStretch = true;

    procedure DisplayList(title: Text; jsonData: Text);
    event OnJsReady();

}

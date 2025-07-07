page 50104 ChiizuRoleCenter
{
    PageType = RoleCenter;
    ApplicationArea = All;
    Caption = 'Chiizu Role Center';

    layout
    {
        area(roleCenter)
        {
            group(ChiizuGroup)
            {
                Caption = 'Chiizu';

                part(CustomersPart; CustomersPage)
                {
                    ApplicationArea = All;
                    Caption = 'Customers';
                }

                part(InvoicesPart; InvoicesPage)
                {
                    ApplicationArea = All;
                    Caption = 'Invoices';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OpenCustomers)
            {
                Caption = 'Customers';
                ApplicationArea = All;
                RunObject = Page CustomersPage;
            }

            action(OpenInvoices)
            {
                Caption = 'Invoices';
                ApplicationArea = All;
                RunObject = Page InvoicesPage;
            }
        }
    }
}

page 50101 "Chiizu Purchase Invoices"
{
    PageType = List;
    ApplicationArea = All;
    SourceTable = "Purch. Inv. Header";
    Caption = 'Chiizu — Purchase Invoices';

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("No."; Rec."No.")
                {
                    Caption = 'Invoice No';
                    ApplicationArea = All;
                }

                field("Buy-from Vendor Name"; Rec."Buy-from Vendor Name")
                {
                    Caption = 'Vendor Name';
                    ApplicationArea = All;
                }

                field("Pay-to Contact"; Rec."Pay-to Contact")
                {
                    Caption = 'Contact';
                    ApplicationArea = All;
                }

                field("Due Date"; Rec."Due Date")
                {
                    ApplicationArea = All;
                }

                field("Amount Including VAT"; Rec."Amount Including VAT")
                {
                    Caption = 'Invoice Amount';
                    ApplicationArea = All;
                }

                field("Remaining Amount"; Rec."Remaining Amount")
                {
                    Caption = 'Remaining Amount';
                    ApplicationArea = All;
                }

                // ✅ ADD THIS FIELD HERE
                field("Chiizu Paid"; IsChiizuPaid())
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(PayWithChiizu)
            {
                ApplicationArea = All;
                Caption = 'Pay Selected Invoices';
                Image = Payment;

                trigger OnAction()
                var
                    SelectedInvoices: Record "Purch. Inv. Header";
                    PaymentService: Codeunit "Chiizu Payment Service";
                    InvoiceCount: Integer;
                begin
                    CurrPage.SetSelectionFilter(SelectedInvoices);

                    if SelectedInvoices.IsEmpty() then
                        Error('Please select at least one invoice.');

                    InvoiceCount := SelectedInvoices.Count();

                    PaymentService.PayPurchaseInvoicesBulk(SelectedInvoices);

                    Commit();

                    Message(
                        '%1 purchase invoice(s) submitted for payment via Chiizu.',
                        InvoiceCount
                    );

                    CurrPage.Update(false);
                end;
            }
        }
    }

    local procedure IsChiizuPaid(): Boolean
    var
        Status: Record "Chiizu Invoice Status";
    begin
        if Status.Get(Rec."No.") then
            exit(Status."Paid via Chiizu");

        exit(false);
    end;
}

pageextension 50101 "Chiizu Purch Invoices Ext" extends "Purchase Invoices"
{
    Caption = 'Hardik | Purchase Invoices';

    layout
    {
        modify("Due Date")
        {
            Visible = true;
        }

        modify("Status")
        {
            Visible = true;
        }

        modify("Location Code")
        {
            Visible = false;
        }

        modify("Assigned User ID")
        {
            Visible = false;
        }

        addafter("Amount")
        {
            field("Payable Amount"; Rec."Amount Including VAT")
            {
                ApplicationArea = All;
                Caption = 'Payable Amount';
                ToolTip = 'Full invoice amount (invoice not posted yet). Includes VAT.';
            }
        }

        addafter("Status")
        {
            field("Chiizu Paid"; IsChiizuPaid())
            {
                ApplicationArea = All;
                ToolTip = 'Specifies whether this invoice was paid via Chiizu.';
            }
        }
    }

    actions
    {
        addlast(Processing)
        {
            action(PayWithChiizu)
            {
                Caption = 'Pay with Chiizu';
                Image = Payment;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    PurchHeader: Record "Purchase Header";
                    PaymentService: Codeunit "Chiizu Payment Service";
                begin
                    CurrPage.SetSelectionFilter(PurchHeader);

                    if PurchHeader.IsEmpty() then
                        Error('Please select at least one purchase invoice.');

                    PaymentService.PayPurchaseInvoicesBulk(PurchHeader);

                    Message('Selected invoice(s) were successfully paid via Chiizu.');
                end;

            }
        }
    }

    // -----------------------------
    // Helpers
    // -----------------------------
    local procedure IsChiizuPaid(): Boolean
    var
        Status: Record "Chiizu Invoice Status";
    begin
        if Status.Get(Rec."No.") then
            exit(Status."Paid via Chiizu");

        exit(false);
    end;
}

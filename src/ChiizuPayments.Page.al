page 50101 "Chiizu Payments"
{
    PageType = List;
    ApplicationArea = All;
    SourceTable = "Vendor Ledger Entry";
    Caption = 'Chiizu — Pay Invoices';

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Document No."; Rec."Document No.") { }
                field("Vendor No."; Rec."Vendor No.") { }
                field("Remaining Amount"; Rec."Remaining Amount") { }
                field("Chiizu Paid"; Rec."Chiizu Paid") { }
            }

            // ✅ Proper part control here
            usercontrol(ChiizuPayments; "ChiizuPayments")
            {
                ApplicationArea = All;
                Visible = true;
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
                    Selected: Record "Vendor Ledger Entry";
                begin
                    CurrPage.Update(false);
                    Selected := Rec;
                    Message('Open the Chiizu control to complete payment (mock).');
                end;
            }
        }
    }
}

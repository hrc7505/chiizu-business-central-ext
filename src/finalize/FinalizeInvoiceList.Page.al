page 50108 "Chiizu Finalize Invoice List"
{
    PageType = ListPart;
    SourceTable = "Purch. Inv. Header";
    ApplicationArea = All;

    SourceTableTemporary = true;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.") { ApplicationArea = All; }
                field("Buy-from Vendor Name"; Rec."Buy-from Vendor Name") { ApplicationArea = All; }
                field("Remaining Amount"; Rec."Remaining Amount") { ApplicationArea = All; }
                field("Amount Including VAT"; Rec."Amount Including VAT") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RemoveFromList)
            {
                Caption = 'Delete Invoice';
                Image = Delete;

                trigger OnAction()
                begin
                    Rec.CalcFields("Remaining Amount");
                    TotalAmount -= Abs(Rec."Remaining Amount");

                    Rec.Delete();
                    CurrPage.Update(true);
                end;
            }
        }
    }

    var
        TotalAmount: Decimal;

    procedure GetTotalAmount(): Decimal
    begin
        exit(TotalAmount);
    end;

    procedure SetInvoices(InvoiceNos: List of [Code[20]])
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        i: Integer;
    begin
        Rec.Reset();
        Rec.DeleteAll();
        TotalAmount := 0;

        for i := 1 to InvoiceNos.Count() do begin
            PurchInvHeader.Get(InvoiceNos.Get(i));
            PurchInvHeader.CalcFields("Remaining Amount");

            Rec := PurchInvHeader;
            Rec.Insert();

            TotalAmount += Abs(PurchInvHeader."Remaining Amount");
        end;
    end;
}

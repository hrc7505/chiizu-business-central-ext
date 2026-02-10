page 50108 "Chiizu Finalize Invoice List"
{
    PageType = ListPart;
    SourceTable = "Purch. Inv. Header";
    SourceTableTemporary = true;
    Caption = 'Invoices to Pay';
    Editable = true;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = true;

    layout
    {
        area(content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.") { ApplicationArea = All; Editable = false; }
                field("Buy-from Vendor Name"; Rec."Buy-from Vendor Name") { ApplicationArea = All; Editable = false; }
                field("Remaining Amount"; Rec."Remaining Amount") { ApplicationArea = All; Editable = false; }
                field("Amount Including VAT"; Rec."Amount Including VAT") { ApplicationArea = All; Editable = false; }
            }
        }
    }

    // 🛑 THE CRITICAL FIX: Overriding the standard delete trigger
    trigger OnDeleteRecord(): Boolean
    begin
        // Delete(false) skips the Table-level OnDelete trigger that causes your error
        Rec.Delete(false);

        // Refresh the parent page totals
        CurrPage.Update(false);

        // Return FALSE to tell BC "I have already handled the deletion, don't do it again"
        exit(false);
    end;

    procedure SetInvoices(InvoiceNos: List of [Code[20]])
    var
        RealPurchInv: Record "Purch. Inv. Header";
        InvNo: Code[20];
    begin
        Rec.Reset();
        Rec.DeleteAll();

        foreach InvNo in InvoiceNos do begin
            if RealPurchInv.Get(InvNo) then begin
                Rec.Init();
                Rec.TransferFields(RealPurchInv);
                // Use Insert(false) here as well just to be safe
                Rec.Insert(false);
            end;
        end;

        if Rec.FindFirst() then;
    end;

    procedure GetRemainingInvoiceNos(var ResultList: List of [Code[20]])
    begin
        Clear(ResultList);
        // We look at our temporary buffer to see what is left
        if Rec.FindSet() then
            repeat
                ResultList.Add(Rec."No.");
            until Rec.Next() = 0;
    end;
}
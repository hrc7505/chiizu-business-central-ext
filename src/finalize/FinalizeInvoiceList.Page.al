page 50108 "Chiizu Finalize Invoice List"
{
    PageType = ListPart;
    SourceTable = "Purch. Inv. Header";
    ApplicationArea = All;
    Editable = false;

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

    procedure SetInvoices(InvoiceNos: List of [Code[20]])
    var
        FilterTxt: Text;
        i: Integer;
    begin
        Rec.Reset();

        for i := 1 to InvoiceNos.Count() do
            FilterTxt += InvoiceNos.Get(i) + '|';

        FilterTxt := DelChr(FilterTxt, '>', '|');

        Rec.SetFilter("No.", FilterTxt);
    end;
}

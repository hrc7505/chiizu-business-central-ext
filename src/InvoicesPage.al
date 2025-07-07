/* 
page 50101 InvoicesPage
{

    Caption = 'Invoices BY CHIIZU';
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = "Sales Invoice Header";
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            usercontrol(InvoicesControl; InvoicessControlAddIn)
            {
                ApplicationArea = All;

                trigger OnJsReady()
                var
                    InvoiceRec: Record "Sales Invoice Header";
                    InvoiceArray: JsonArray;
                    InvoiceObj: JsonObject;
                    JsonText: Text;
                begin
                    if HasInitialized then
                        exit;

                    HasInitialized := true;

                    InvoiceRec.Reset();
                    if InvoiceRec.FindSet() then begin
                        repeat
                            Clear(InvoiceObj);
                            InvoiceObj.Add('Amount', InvoiceRec.Amount);
                            InvoiceObj.Add('No', InvoiceRec."No.");
                            InvoiceArray.Add(InvoiceObj);
                        until InvoiceRec.Next() = 0;
                    end;

                    InvoiceArray.WriteTo(JsonText);
                    CurrPage.InvoicesControl.DisplayList('Invoices', JsonText);
                end;

            }
        }
    }

    var
        JsonText: Text;
        HasInitialized: Boolean;
}
 */


page 50101 InvoicesPage
{
    Caption = 'Invoices BY CHIIZU';
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = "Sales Invoice Header";
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            usercontrol(InvoicesControl; InvoicessControlAddIn)
            {
                ApplicationArea = All;

                trigger OnJsReady()
                begin
                    HasInitialized := true;
                    CurrentPageNo := 1;
                    LoadInvoicesPage(CurrentPageNo);
                end;

                trigger loadMore()
                begin
                    // if hasMore then
                    CurrentPageNo += 1;
                    //  if hasMore then
                    hasMore := LoadInvoicesPage(CurrentPageNo);
                end;
            }
        }
    }

    var
        HasInitialized: Boolean;
        CurrentPageNo: Integer;
        PageSize: Integer;
        InvoiceArray: JsonArray;
        InvoiceObj: JsonObject;
        JsonText: Text;
        hasMore: Boolean;

    procedure LoadInvoicesPage(PageNo: Integer) Result: Boolean
    var
        InvoiceRec: Record "Sales Invoice Header";
        SkipCount: Integer;
        CountLoaded: Integer;
        i: Integer;
    begin
        PageSize := 20;
        Clear(InvoiceArray);
        SkipCount := (PageNo - 1) * PageSize;
        CountLoaded := 0;

        if InvoiceRec.FindSet() then begin
            // Skip records for paging
            for i := 1 to SkipCount do begin
                if InvoiceRec.Next() = 0 then
                    exit(false); // no more records after skip, so no more pages
            end;

            repeat
                Clear(InvoiceObj);
                InvoiceObj.Add('Amount', InvoiceRec.Amount);
                InvoiceObj.Add('No', InvoiceRec."No.");
                InvoiceArray.Add(InvoiceObj);

                CountLoaded += 1;
                if CountLoaded >= PageSize then
                    break;
            until InvoiceRec.Next() = 0;

            InvoiceArray.WriteTo(JsonText);

            if PageNo = 1 then
                CurrPage.InvoicesControl.DisplayList('Invoices', JsonText)
            else
                CurrPage.InvoicesControl.appendData(JsonText);

            // Return true if this page is full (means maybe more records)
            // Return false if fewer records than page size, means end
            exit(CountLoaded = PageSize);
        end;

        // No records at all
        exit(false);
    end;

}


codeunit 50104 "Chiizu Payment Service"
{
    procedure PayInvoices(SelectedInvoiceNos: List of [Code[20]])
    var
        Setup: Record "Chiizu Setup";
        Status: Record "Chiizu Invoice Status";
        VendLedgEntry: Record "Vendor Ledger Entry";
        Payload: JsonObject;
        Invoices: JsonArray;
        Obj: JsonObject;
        InvoiceNosToMarkPaid: List of [Code[20]];
        InvNo: Code[20];
        i: Integer;
        ErrorText: Text;
        HasErrors: Boolean;
        RemainingAmount: Decimal;
        CurrencyCode: Code[10];
    begin
        if SelectedInvoiceNos.Count() = 0 then
            Error('No invoices were provided.');

        GetOrCreateSetup(Setup);

        Clear(Payload);
        Clear(Invoices);
        Clear(InvoiceNosToMarkPaid);
        ErrorText := '';
        HasErrors := false;

        // Validate each invoice and build the single payload
        for i := 1 to SelectedInvoiceNos.Count() do begin
            InvNo := SelectedInvoiceNos.Get(i);

            // Find the open Vendor Ledger Entry for the posted purchase invoice
            VendLedgEntry.Reset();
            VendLedgEntry.SetRange("Document Type", VendLedgEntry."Document Type"::Invoice);
            VendLedgEntry.SetRange("Document No.", InvNo);
            VendLedgEntry.SetRange(Open, true);

            if not VendLedgEntry.FindFirst() then begin
                ErrorText += StrSubstNo('• No open vendor ledger entry found for invoice %1.\%2', InvNo, '');
                HasErrors := true;
                continue;
            end;

            VendLedgEntry.CalcFields("Remaining Amount", "Remaining Amt. (LCY)");

            // Remaining Amount is often negative for payables; use absolute value
            RemainingAmount := Abs(VendLedgEntry."Remaining Amount");

            if Round(RemainingAmount, 0.01, '=') = 0 then begin
                ErrorText += StrSubstNo('• Invoice %1 has no remaining payable amount.\%2', InvNo, '');
                HasErrors := true;
                continue;
            end;

            // Check if already marked as paid via Chiizu
            if Status.Get(InvNo) then
                if Status."Paid via Chiizu" then begin
                    ErrorText += StrSubstNo('• Invoice %1 is already paid via Chiizu.\%2', InvNo, '');
                    HasErrors := true;
                    continue;
                end;

            // Build object for this invoice (positive amount)
            Clear(Obj);
            Obj.Add('invoiceNo', InvNo);
            Obj.Add('vendorNo', VendLedgEntry."Vendor No.");
            Obj.Add('amount', RemainingAmount);
            Obj.Add('postingDate', Format(VendLedgEntry."Posting Date"));
            CurrencyCode := VendLedgEntry."Currency Code";
            if CurrencyCode <> '' then
                Obj.Add('currency', CurrencyCode)
            else
                Obj.Add('currency', 'LCY'); // Adjust to your API's convention

            Invoices.Add(Obj);
            InvoiceNosToMarkPaid.Add(InvNo);
        end;

        // If any invoice failed validation, stop and show aggregated errors
        if HasErrors then
            Error(ErrorText);

        if Invoices.Count() = 0 then
            Error('None of the selected invoices are payable.');

        // Final bulk payload
        Payload.Add('batchId', CreateBatchId());
        Payload.Add('invoices', Invoices);

        // Single API call
        CallBulkPaymentAPI(Setup, Payload);

        // Mark all included invoices as paid via Chiizu
        for i := 1 to InvoiceNosToMarkPaid.Count() do begin
            InvNo := InvoiceNosToMarkPaid.Get(i);

            if not Status.Get(InvNo) then begin
                Status.Init();
                Status."Invoice No." := InvNo;
                Status."Paid via Chiizu" := true;
                Status."Payment Date" := Today();
                Status.Insert(true);
            end else begin
                Status."Paid via Chiizu" := true;
                Status."Payment Date" := Today();
                Status.Modify(true);
            end;
        end;
    end;

    local procedure CallBulkPaymentAPI(Setup: Record "Chiizu Setup"; Payload: JsonObject)
    var
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Content: HttpContent;
        Headers: HttpHeaders;
        BodyText: Text;
        ResponseText: Text;
    begin
        // Serialize payload to text content
        Payload.WriteTo(BodyText);
        Content.WriteFrom(BodyText);

        // Content headers
        Content.GetHeaders(Headers);
        Headers.Clear();
        Headers.Add('Content-Type', 'application/json');

        // Auth header (replace with your token handling)
        Headers := Client.DefaultRequestHeaders();
        Headers.Clear();
        Headers.Add('Authorization', 'Bearer {PASS_TOKEN_HERE}');

        Request.Method := 'POST';
        Request.SetRequestUri(Setup."API Base URL");
        Request.Content := Content;

        if not Client.Send(Request, Response) then
            Error('Failed to call Chiizu payment API.');

        if not Response.IsSuccessStatusCode() then begin
            Response.Content.ReadAs(ResponseText);
            Error('Chiizu payment failed. Status: %1, Response: %2',
                  Response.HttpStatusCode(), ResponseText);
        end;
    end;

    local procedure CreateBatchId(): Code[50]
    begin
        exit('BC-' + Format(CurrentDateTime(), 0, '<Year4><Month,2><Day,2><Hour,2><Minute,2><Second,2>'));
    end;

    local procedure GetOrCreateSetup(var Setup: Record "Chiizu Setup")
    begin
        if not Setup.Get('CHIIZU') then begin
            Setup.Init();
            Setup."Primary Key" := 'CHIIZU';
            Setup.Insert(true);
        end;
    end;
}

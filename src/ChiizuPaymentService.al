codeunit 50104 "Chiizu Payment Service"
{
    // ==================================================
    // PUBLIC API – PAY POSTED INVOICE (LEDGER BASED)
    // ==================================================
    procedure PayVendorLedgerEntry(var VendLedgEntry: Record "Vendor Ledger Entry")
    var
        Setup: Record "Chiizu Setup";
        Payload: JsonObject;
        Invoices: JsonArray;
        InvoiceNos: List of [Code[20]];
    begin
        GetOrCreateSetup(Setup);

        if Setup."API Base URL" = '' then
            Error('Chiizu API Base URL is missing.');

        if not VendLedgEntry.Open then
            Error('Vendor ledger entry is already closed.');

        Invoices := BuildLedgerInvoiceArray(VendLedgEntry, InvoiceNos);

        if Invoices.Count() = 0 then
            Error('No valid invoices found for payment.');

        Payload.Add('batchId', CreateBatchId());
        Payload.Add('invoices', Invoices);

        CallBulkPaymentAPI(Setup, Payload);

        MarkInvoicesPaid(InvoiceNos);
    end;

    // ==================================================
    // BUILD JSON FROM VENDOR LEDGER ENTRY (POSTED)
    // ==================================================
    local procedure BuildLedgerInvoiceArray(
        var VendLedgEntry: Record "Vendor Ledger Entry";
        var InvoiceNos: List of [Code[20]]
    ): JsonArray
    var
        Obj: JsonObject;
        Arr: JsonArray;
        Status: Record "Chiizu Invoice Status";
        RemainingAmount: Decimal;
    begin
        VendLedgEntry.CalcFields("Remaining Amount");
        RemainingAmount := VendLedgEntry."Remaining Amount";

        if RemainingAmount <= 0 then
            Error(
                'Invoice %1 has no remaining payable amount.',
                VendLedgEntry."Document No."
            );

        if Status.Get(VendLedgEntry."Document No.") then
            if Status."Paid via Chiizu" then
                Error(
                    'Invoice %1 is already paid via Chiizu.',
                    VendLedgEntry."Document No."
                );

        Clear(Obj);
        Obj.Add('invoiceNo', VendLedgEntry."Document No.");
        Obj.Add('vendorNo', VendLedgEntry."Vendor No.");
        Obj.Add('amount', RemainingAmount);
        Obj.Add('postingDate', Format(VendLedgEntry."Posting Date"));

        Arr.Add(Obj);
        InvoiceNos.Add(VendLedgEntry."Document No.");

        exit(Arr);
    end;

    // ==================================================
    // HTTP CALL
    // ==================================================
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
        Payload.WriteTo(BodyText);
        Content.WriteFrom(BodyText);

        Content.GetHeaders(Headers);
        Headers.Clear();
        Headers.Add('Content-Type', 'application/json');

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
            Error(
                'Chiizu payment failed. Status: %1, Response: %2',
                Response.HttpStatusCode(),
                ResponseText
            );
        end;
    end;

    // ==================================================
    // STATUS TABLE
    // ==================================================
    local procedure MarkInvoicesPaid(InvoiceNos: List of [Code[20]])
    var
        Status: Record "Chiizu Invoice Status";
        InvoiceNo: Code[20];
    begin
        foreach InvoiceNo in InvoiceNos do begin
            if not Status.Get(InvoiceNo) then begin
                Status.Init();
                Status."Invoice No." := InvoiceNo;
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

    // ==================================================
    // HELPERS
    // ==================================================
    local procedure CreateBatchId(): Code[50]
    begin
        exit(
            'BC-' +
            Format(CurrentDateTime(), 0, '<Year4><Month,2><Day,2><Hour,2><Minute,2><Second,2>')
        );
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

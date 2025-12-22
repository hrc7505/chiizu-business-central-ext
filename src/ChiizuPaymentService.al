codeunit 50104 "Chiizu Payment Service"
{
    procedure PayVendorInvoicesBulk(var VendLedgEntry: Record "Vendor Ledger Entry")
    var
        Setup: Record "Chiizu Setup";
        Payload: JsonObject;
        Invoices: JsonArray;
    begin
        GetOrCreateSetup(Setup);

        if Setup."API Base URL" = '' then begin
            Page.Run(Page::"Chiizu Setup");
            Error('Please configure Chiizu API Base URL.');
        end;

        if Setup."API Key" = '' then begin
            Page.Run(Page::"Chiizu Setup");
            Error('Please configure Chiizu API Key.');
        end;

        Invoices := BuildInvoiceArray(VendLedgEntry);

        Clear(Payload);
        Payload.Add('batchId', CreateBatchId());
        Payload.Add('invoices', Invoices);

        // ✅ ONE HTTP call
        CallBulkPaymentAPI(Setup, Payload);

        // ✅ Mark invoices as paid AFTER success
        MarkInvoicesAsPaid(VendLedgEntry);
    end;

    // --------------------------------------------------
    // Build JSON array from selected invoices
    // --------------------------------------------------
    local procedure BuildInvoiceArray(var VendLedgEntry: Record "Vendor Ledger Entry"): JsonArray
    var
        Obj: JsonObject;
        Arr: JsonArray;
    begin
        if VendLedgEntry.FindSet() then
            repeat
                if VendLedgEntry."Remaining Amount" < 0 then // Todo: After testing please make this check to <=
                    Error(
                        'Invoice %1 has no remaining amount.',
                        VendLedgEntry."Document No."
                    );

                if VendLedgEntry."Chiizu Paid" then
                    Error(
                        'Invoice %1 is already paid via Chiizu.',
                        VendLedgEntry."Document No."
                    );

                Clear(Obj);
                Obj.Add('invoiceNo', VendLedgEntry."Document No.");
                Obj.Add('vendorNo', VendLedgEntry."Vendor No.");
                Obj.Add('amount', VendLedgEntry."Remaining Amount");

                Arr.Add(Obj);
            until VendLedgEntry.Next() = 0;

        exit(Arr);
    end;

    // --------------------------------------------------
    // HTTP bulk payment call
    // --------------------------------------------------
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
        Headers.Add('Authorization', 'Bearer ' + Setup."API Key");

        Request.Method := 'POST';
        Request.SetRequestUri(Setup."API Base URL");
        Request.Content := Content;

        if not Client.Send(Request, Response) then
            Error('Failed to call Chiizu bulk payment API.');

        if not Response.IsSuccessStatusCode() then begin
            Response.Content.ReadAs(ResponseText);
            Error(
                'Chiizu bulk payment failed. Status: %1, Response: %2',
                Response.HttpStatusCode(),
                ResponseText
            );
        end;
    end;

    // --------------------------------------------------
    // Mark all invoices as paid
    // --------------------------------------------------
    local procedure MarkInvoicesAsPaid(var VendLedgEntry: Record "Vendor Ledger Entry")
    begin
        if VendLedgEntry.FindSet(true) then
            repeat
                VendLedgEntry.Validate("Chiizu Paid", true);
                VendLedgEntry.Modify(true);
            until VendLedgEntry.Next() = 0;
    end;

    // --------------------------------------------------
    // Helpers
    // --------------------------------------------------
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

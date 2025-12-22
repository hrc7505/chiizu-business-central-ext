codeunit 50104 "Chiizu Payment Service"
{
    procedure PayPurchaseInvoicesBulk(var PurchInvHeader: Record "Purch. Inv. Header")
    var
        Setup: Record "Chiizu Setup";
        Payload: JsonObject;
        Invoices: JsonArray;
        InvoiceNos: List of [Code[20]];
    begin
        GetOrCreateSetup(Setup);

        if Setup."API Base URL" = '' then
            Error('Chiizu API Base URL is missing.');

        if Setup."API Key" = '' then
            Error('Chiizu API Key is missing.');

        // Build payload + collect invoice numbers
        Invoices := BuildPurchaseInvoiceArray(PurchInvHeader, InvoiceNos);

        if Invoices.Count() = 0 then
            Error('No valid invoices found for payment.');

        Clear(Payload);
        Payload.Add('batchId', CreateBatchId());
        Payload.Add('invoices', Invoices);

        // Single bulk API call
        CallBulkPaymentAPI(Setup, Payload);

        // Mark ALL invoices as paid
        MarkInvoicesPaid(InvoiceNos);
    end;

    // --------------------------------------------------
    // Build JSON array from selected invoices
    // --------------------------------------------------
    local procedure BuildPurchaseInvoiceArray(
        var PurchInvHeader: Record "Purch. Inv. Header";
        var InvoiceNos: List of [Code[20]]
    ): JsonArray
    var
        Obj: JsonObject;
        Arr: JsonArray;
        Status: Record "Chiizu Invoice Status";
    begin
        if PurchInvHeader.FindSet() then
            repeat
                if PurchInvHeader."Remaining Amount" < 0 then
                    Error(
                        'Invoice %1 has no remaining amount.',
                        PurchInvHeader."No."
                    );

                // Check status table instead of posted invoice
                if Status.Get(PurchInvHeader."No.") then
                    if Status."Paid via Chiizu" then
                        Error(
                            'Invoice %1 is already paid via Chiizu.',
                            PurchInvHeader."No."
                        );

                Clear(Obj);
                Obj.Add('invoiceNo', PurchInvHeader."No.");
                Obj.Add('vendorNo', PurchInvHeader."Buy-from Vendor No.");
                Obj.Add('amount', PurchInvHeader."Remaining Amount");
                Obj.Add('dueDate', Format(PurchInvHeader."Due Date"));

                Arr.Add(Obj);
                InvoiceNos.Add(PurchInvHeader."No.");

            until PurchInvHeader.Next() = 0;

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
    // Mark ALL invoices as paid
    // --------------------------------------------------
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

    // --------------------------------------------------
    // Helpers
    // --------------------------------------------------
    local procedure CreateBatchId(): Code[50]
    begin
        exit(
            'BC-' +
            Format(
                CurrentDateTime(),
                0,
                '<Year4><Month,2><Day,2><Hour,2><Minute,2><Second,2>'
            )
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

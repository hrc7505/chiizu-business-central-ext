codeunit 50104 "Chiizu Payment Service"
{
    procedure PayVendorInvoice(var VendLedgEntry: Record "Vendor Ledger Entry")
    var
        Setup: Record "Chiizu Setup";
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Content: HttpContent;
        ContentHeaders: HttpHeaders;
        RequestHeaders: HttpHeaders;
        Body: JsonObject;
        RequestBody: Text;
        ResponseText: Text;
    begin
        // Ensure setup exists
        GetOrCreateSetup(Setup);

        // Validate setup
        if Setup."API Base URL" = '' then begin
            Page.Run(Page::"Chiizu Setup");
            Error('Please configure Chiizu Setup before paying invoices.');
        end;

        if Setup."API Key" = '' then begin
            Page.Run(Page::"Chiizu Setup");
            Error('Please configure Chiizu Setup before paying invoices.');
        end;


        // Build JSON body
        Body.Add('invoiceNo', VendLedgEntry."Document No.");
        Body.Add('vendorNo', VendLedgEntry."Vendor No.");
        Body.Add('amount', VendLedgEntry."Remaining Amount");

        Body.WriteTo(RequestBody);
        Content.WriteFrom(RequestBody);

        // Content headers (ONLY content-related headers allowed)
        Content.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        ContentHeaders.Add('Content-Type', 'application/json');

        // Request headers (Authorization MUST be here)
        RequestHeaders := Client.DefaultRequestHeaders();
        RequestHeaders.Clear();
        RequestHeaders.Add('Authorization', 'Bearer ' + Setup."API Key");

        // Build request
        Request.Method := 'POST';
        Request.SetRequestUri(Setup."API Base URL" /* + '/payments/pay' */);
        Request.Content := Content;

        // Send request
        Client.Send(Request, Response);

        if not Response.IsSuccessStatusCode() then begin
            Response.Content.ReadAs(ResponseText);
            Error(
                'Chiizu payment failed. Status: %1, Response: %2',
                Response.HttpStatusCode(),
                ResponseText
            );
        end;

        // Mark as paid
        VendLedgEntry.Validate("Chiizu Paid", true);
        VendLedgEntry.Modify(true);
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

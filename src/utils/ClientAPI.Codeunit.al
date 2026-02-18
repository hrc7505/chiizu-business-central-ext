codeunit 50110 "Chiizu API Client"
{
    procedure PostJson(Endpoint: Text; Payload: JsonObject): JsonObject
    var
        Setup: Record "Chiizu Setup";
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Content: HttpContent;
        ContentHeaders: HttpHeaders;
        RequestHeaders: HttpHeaders;
        BodyText: Text;
        ResponseText: Text;
        JsonResp: JsonObject;
        SetupMgmt: Codeunit "Chiizu Setup Management";
    begin
        // -----------------------------
        // Load setup (REQUIRED)
        // -----------------------------
        SetupMgmt.GetSetup(Setup);

        // -----------------------------
        // Serialize payload
        // -----------------------------
        Payload.WriteTo(BodyText);
        Content.WriteFrom(BodyText);

        // -----------------------------
        // Content headers
        // -----------------------------
        Content.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        ContentHeaders.Add('Content-Type', 'application/json');

        // -----------------------------
        // Request
        // -----------------------------
        Request.Method := 'POST';
        Request.SetRequestUri(Setup."API Base URL" + '/api' + Endpoint);
        Request.Content := Content;

        // -----------------------------
        // Request headers (IMPORTANT)
        // -----------------------------
        Request.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Authorization', 'Bearer ' + Setup."API Key");


        if not Client.Send(Request, Response) then
            Error('Failed to reach Chiizu API.');

        Response.Content.ReadAs(ResponseText);

        // -----------------------------
        // HTTP error handling
        // -----------------------------
        if not Response.IsSuccessStatusCode() then
            Error(
                'Chiizu API error (%1): %2',
                Response.HttpStatusCode(),
                ResponseText
            );

        // -----------------------------
        // Parse JSON
        // -----------------------------
        JsonResp.ReadFrom(ResponseText);
        exit(JsonResp);
    end;

    procedure GetJson(Endpoint: Text): JsonObject
    var
        Setup: Record "Chiizu Setup";
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        ResponseText: Text;
        JsonResp: JsonObject;
        SetupMgmt: Codeunit "Chiizu Setup Management";
    begin
        SetupMgmt.GetSetup(Setup);

        Request.Method := 'GET';
        Request.SetRequestUri(Setup."API Base URL" + '/api' + Endpoint);

        Request.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Authorization', 'Bearer ' + Setup."API Key");

        if not Client.Send(Request, Response) then
            Error('Failed to reach Chiizu API.');

        Response.Content.ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            Error('Chiizu API error (%1): %2', Response.HttpStatusCode(), ResponseText);

        JsonResp.ReadFrom(ResponseText);
        exit(JsonResp);
    end;
}

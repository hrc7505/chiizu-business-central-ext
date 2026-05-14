namespace Chiizu.Utils;

using Chiizu;
using Chiizu.Installation;

codeunit 1000010 "Chiizu API Client"
{
    procedure PostJson(Endpoint: Text; Payload: JsonObject): JsonObject
    var
        Setup: Record "Chiizu Setup";
        SetupMgmt: Codeunit "Chiizu Setup Management";
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Content: HttpContent;
        ContentHeaders: HttpHeaders;
        RequestHeaders: HttpHeaders;
        BodyText: Text;
        ResponseText: Text;
        JsonResp: JsonObject;
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

        if not Client.Send(Request, Response) then Error('Failed to reach Chiizu API.');

        Response.Content.ReadAs(ResponseText);

        // -----------------------------
        // HTTP error handling
        // -----------------------------
        if not Response.IsSuccessStatusCode() then
            Error('Chiizu API error (%1): %2', Response.HttpStatusCode(), ResponseText);

        // -----------------------------
        // Parse JSON
        // -----------------------------
        JsonResp.ReadFrom(ResponseText);
        exit(JsonResp);
    end;

    procedure GetJson(Endpoint: Text): JsonObject
    var
        Setup: Record "Chiizu Setup";
        SetupMgmt: Codeunit "Chiizu Setup Management";
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        ResponseText: Text;
        JsonResp: JsonObject;
    begin
        SetupMgmt.GetSetup(Setup);

        Request.Method := 'GET';
        Request.SetRequestUri(Setup."API Base URL" + '/api' + Endpoint);

        Request.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Authorization', 'Bearer ' + Setup."API Key");

        if not Client.Send(Request, Response) then Error('Failed to reach Chiizu API.');

        Response.Content.ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            Error('Chiizu API error (%1): %2', Response.HttpStatusCode(), ResponseText);

        JsonResp.ReadFrom(ResponseText);
        exit(JsonResp);
    end;

    // --- GLOBAL JSON HELPERS ---
    procedure GetJsonString(Obj: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Obj.Get(KeyName, Token) then
            if not Token.AsValue().IsNull() then exit(Token.AsValue().AsText());
        exit('');
    end;

    procedure GetJsonDate(Obj: JsonObject; KeyName: Text): Date
    var
        Token: JsonToken;
        DateVar: Date;
        DateText: Text;
    begin
        if Obj.Get(KeyName, Token) then
            if not Token.AsValue().IsNull() then begin
                DateText := CopyStr(Token.AsValue().AsText(), 1, 10);
                if Evaluate(DateVar, DateText, 9) then exit(DateVar);
            end;
        exit(0D);
    end;

    procedure GetJsonDecimal(Obj: JsonObject; KeyName: Text): Decimal
    var
        Token: JsonToken;
        ResultDec: Decimal;
    begin
        if Obj.Get(KeyName, Token) then
            if not Token.AsValue().IsNull() then
                if Evaluate(ResultDec, Token.AsValue().AsText()) then exit(ResultDec);
        exit(0.0);
    end;
}
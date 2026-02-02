codeunit 50111 "Chiizu Connection Service"
{
    procedure TestConnection(): Code[50]
    var
        ApiClient: Codeunit "Chiizu API Client";
        Payload: JsonObject;
        Response: JsonObject;
        TenantToken: JsonToken;
        TenantIdTxt: Text;
    begin
        Payload.Add('ping', true);

        Response := ApiClient.PostJson('/connect-chiizu', Payload);

        if not Response.Get('tenantId', TenantToken) then
            Error('Invalid Chiizu response: tenantId missing.');

        TenantIdTxt := TenantToken.AsValue().AsText();

        exit(TenantIdTxt);
    end;
}

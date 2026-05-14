namespace Chiizu.Installation;

using Chiizu.Utils;

codeunit 1000011 "Chiizu Connection Service"
{
    procedure Connect(): Code[50]
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

        exit(CopyStr(TenantIdTxt, 1, 50));
    end;

    procedure Disconnect(): Boolean
    var
        ApiClient: Codeunit "Chiizu API Client";
        Payload: JsonObject;
        Response: JsonObject;
        isDisconnectedToken: JsonToken;
        isDisconnected: Boolean;
    begin
        Payload.Add('ping', true);

        Response := ApiClient.PostJson('/disconnect-chiizu', Payload);

        if not Response.Get('isDisconnected', isDisconnectedToken) then
            Error('Invalid Chiizu response: isDisconnected missing.');

        isDisconnected := isDisconnectedToken.AsValue().AsBoolean();

        exit(isDisconnected);
    end;
}

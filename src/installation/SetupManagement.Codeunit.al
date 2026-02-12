codeunit 50108 "Chiizu Setup Management"
{
    procedure GetSetup(var Setup: Record "Chiizu Setup")
    begin
        if not Setup.Get('SETUP') then
            Error('Chiizu setup is not initialized.');
    end;

    procedure EnsureConnected(): Record "Chiizu Setup"
    var
        Setup: Record "Chiizu Setup";
    begin
        // Use your existing GetSetup to load the record
        GetSetup(Setup);

        if Setup."API Base URL" = '' then
            Error('Chiizu API Base URL is not configured.');

        if Setup."API Key" = '' then
            Error('Chiizu API Key is missing.');

        if Setup."Last Verified At" = 0DT then
            Error('Chiizu is not connected. Please verify connection.');

        exit(Setup); // 🔹 Return the validated record
    end;

    procedure FetchFundingAccounts(var TempAcc: Record "Chiizu Funding Account" temporary)
    var
        Setup: Record "Chiizu Setup";
        ApiClient: Codeunit "Chiizu API Client";
        ResponseJson: JsonObject;
        AccountArray: JsonArray;
        Token: JsonToken;
        ItemObj: JsonObject; // 🔹 FIX: Changed from ItemToken (JsonToken) to ItemObj (JsonObject)
        i: Integer;
    begin
        Setup := EnsureConnected();

        // Uses the new GET method
        ResponseJson := ApiClient.GetJson('/funding-accounts');

        if not ResponseJson.Get('accounts', Token) then exit;
        AccountArray := Token.AsArray();

        for i := 0 to AccountArray.Count() - 1 do begin
            AccountArray.Get(i, Token);
            ItemObj := Token.AsObject(); // 🔹 FIX: Correctly extracting the object from the token

            TempAcc.Init();
            TempAcc."Account Id" := GetJsonValue(ItemObj, 'id');
            TempAcc.Name := GetJsonValue(ItemObj, 'name');
            TempAcc."Account Number" := GetJsonValue(ItemObj, 'accountNumber');
            TempAcc.Insert();
        end;
    end;

    local procedure GetJsonValue(Obj: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Obj.Get(KeyName, Token) then
            if not Token.AsValue().IsNull() then
                exit(Token.AsValue().AsText());
    end;
}

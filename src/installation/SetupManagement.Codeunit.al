codeunit 50108 "Chiizu Setup Management"
{
    procedure GetSetup(var Setup: Record "Chiizu Setup")
    begin
        if not Setup.Get('SETUP') then
            Error('Chiizu setup is not initialized.');
    end;

    procedure EnsureConnected()
    var
        Setup: Record "Chiizu Setup";
    begin
        GetSetup(Setup);

        if Setup."API Base URL" = '' then
            Error('Chiizu API Base URL is not configured.');

        if Setup."API Key" = '' then
            Error('Chiizu API Key is missing.');

        if Setup."Last Verified At" = 0DT then
            Error('Chiizu is not connected. Please verify connection.');
    end;

}

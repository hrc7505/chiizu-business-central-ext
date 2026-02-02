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

        if not Setup."Setup Completed" then
            Error('Chiizu is not connected. Please complete Chiizu Setup.');
    end;
}

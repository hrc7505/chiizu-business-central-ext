namespace Chiizu;

permissionset 1000003 "ChiizuSetupPerm"
{
    Caption = 'Chiizu Setup Permissions';
    Assignable = true;

    Permissions = tabledata "Chiizu Setup" = RIMD;
}
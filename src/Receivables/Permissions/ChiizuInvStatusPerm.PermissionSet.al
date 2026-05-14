namespace Chiizu;

permissionset 1000010 "ChiizuInvStatusPerm"
{
    Caption = 'Chiizu Invoice Status Permissions';
    Assignable = true;

    Permissions = tabledata "Chiizu Invoice Status" = RIMD;
}

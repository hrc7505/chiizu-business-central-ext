namespace Chiizu.BankAccounts;

permissionset 1000007 "Chiizu Sync Log Perm"
{
    Caption = 'Chiizu Sync Log Permissions';
    Assignable = true;

    Permissions = tabledata "Chiizu Sync Log" = RIMD;
}
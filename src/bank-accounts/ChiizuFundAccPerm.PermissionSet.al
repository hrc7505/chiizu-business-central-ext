namespace Chiizu;
using Chiizu.BankAccounts;

permissionset 1000006 "Chiizu Fund Acc Perm"
{
    Caption = 'Chiizu Funding Permissions';
    Assignable = true;

    Permissions = tabledata "Chiizu Funding Account" = RIMD;
}
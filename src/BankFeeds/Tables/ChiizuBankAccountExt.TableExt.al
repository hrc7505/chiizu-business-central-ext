namespace Chiizu.BankAccounts;

using Microsoft.Bank.BankAccount;

tableextension 1000005 "Chiizu Bank Account Ext" extends "Bank Account"
{
    fields
    {
        field(1000000; "Chiizu Remote Balance"; Decimal)
        {
            Caption = 'Chiizu Remote Balance';
            Editable = false;
            DataClassification = CustomerContent;
        }

        field(1000001; "Chiizu Account Verified"; Boolean)
        {
            Caption = 'Account Verified';
            DataClassification = CustomerContent;
            Editable = false; // Users can't just check this manually; logic must do it.
        }
    }
}

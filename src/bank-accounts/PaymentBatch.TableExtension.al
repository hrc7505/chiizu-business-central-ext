tableextension 50105 "Chiizu Payment Batch Ext" extends "Chiizu Payment Batch"
{
    fields
    {
        field(50; "Bank Account No."; Code[20])
        {
            TableRelation = "Bank Account"."No.";
            Caption = 'Bank Account';
        }

        field(51; "Bank Account Name"; Text[100])
        {
            Editable = false;
            Caption = 'Bank Account Name';
        }
    }
}

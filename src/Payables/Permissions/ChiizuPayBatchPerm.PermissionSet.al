namespace Chiizu;

permissionset 1000030 "ChiizuPayBatchPerm"
{
    Caption = 'Chiizu Payment Batch Permissions';
    Assignable = true;

    Permissions = tabledata "Chiizu Payment Batch" = RIMD;
}

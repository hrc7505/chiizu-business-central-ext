// ----------------------------------
// Invoice state and payment execution state must be correlated, and this table is your single correlation point.
// Invoice ↔ Payment Execution bridge
// ----------------------------------
enum 50111 "Chiizu Payment Status"
{
    Extensible = true;

    // ===== Initial / BC-owned =====
    value(0; Open)
    {
        Caption = 'Open'; // Invoice exists, no payment intent
    }

    // ===== Chiizu workflow =====
    value(1; Scheduled)
    {
        Caption = 'Scheduled'; // Payment scheduled but not initiated
    }

    value(2; Processing)
    {
        Caption = 'Processing'; // External payment in progress
    }

    value(3; ExternalPaid)
    {
        Caption = 'External Paid'; // Money captured, BC not yet posted
    }

    // ===== BC-derived outcomes =====
    value(4; Paid)
    {
        Caption = 'Paid'; // Fully paid and applied in BC
    }

    value(5; "Partially Paid")
    {
        Caption = 'Partially Paid'; // Partially applied in BC
    }

    // ===== Terminal / error states =====
    value(6; Failed)
    {
        Caption = 'Failed'; // External payment failed
    }

    value(7; Cancelled)
    {
        Caption = 'Cancelled'; // Payment cancelled before posting
    }
}

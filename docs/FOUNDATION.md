# Atlas backend foundation

This is a **schema proposal**, not an applied database migration. Create a dedicated Atlas Supabase project before applying `supabase/schema.sql`. Do not reuse MailMyPDF or UCC projects. Set public client values from `.env.example`; never put a service-role key in frontend variables.

Organization creation and membership assignment deliberately require a trusted provisioning service, not browser permissions. Before real customers: implement provisioning, role-based permissions, auth UI, tests for cross-organization access and foreign keys, audit logs and security review. The current dashboard remains demo-only; the data access functions are not yet wired into it.

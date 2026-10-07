-- email_for_username turned any username into an email address for callers
-- who were not signed in. Username login now goes through the
-- login-with-username Edge Function, which calls this with the service role.
revoke execute on function public.email_for_username(text) from public, anon, authenticated;
grant execute on function public.email_for_username(text) to service_role;

# Duo: our shared budget

## 1. What Duo is

Duo is a simple budget app for two people. You both log spending and income on your own phones, and you both see the same numbers, updated live. It works in any modern browser and can sit on your phone's Home Screen like an app.

It has five tabs: **Home**, **Activity**, **+** (add), **Income**, and **Settings**. Your data lives in a free Supabase database that only the two of you can read.

Setting it up takes about 30 minutes, and you only do it once. Take it one step at a time.

---

## 2. Set up the database on Supabase

Supabase holds your shared data. You need a free account there.

1. Go to **supabase.com** and click **Start your project**. Sign up or sign in.
2. Click **New project**. Pick an organisation, give the project a name (for example `duo-budget`), choose a database password and a region close to you, then click **Create new project**. Wait a minute or two while it starts.
3. Run the setup script:
   1. In the left sidebar, click **SQL Editor**.
   2. Click **+ New query** (or **New query**).
   3. Open the `supabase.sql` file from this project, select all of its text, and copy it.
   4. Paste it into the empty query box.
   5. Click **Run**. You should see "Success. No rows returned" or similar. It is safe to run this again later if you need to.
4. Turn on email sign-in and choose how sign-up confirmation works:
   1. In the left sidebar, click **Authentication**, then **Sign In / Providers**.
   2. Click **Email** and make sure it is switched **on**.
   3. Either:
      - **Simplest:** switch **off** "Confirm email". Each of you can then sign in straight after creating an account.
      - **Or keep confirmation on:** each of you clicks the link in the confirmation email. Open that link on the **same phone and browser** where you will use Duo, or it may not sign you in.
5. Set the web address that Supabase sends people back to:
   1. In the left sidebar, under **Authentication**, click **URL Configuration**.
   2. Set **Site URL** to your GitHub Pages address, in this form: `https://<username>.github.io/<repo>/`. Replace `<username>` with your GitHub username and `<repo>` with your repository name. You get this address in section 3, so you can come back to this step then.
   3. Under **Redirect URLs**, add `https://<username>.github.io/<repo>/**` (the same address with `**` on the end).
   4. Click **Save**.
6. Copy the two values the app needs:
   1. Copy the **Project URL**. You can find it on your project's home page (**Overview**), and under **Project Settings → Data API**. It looks like `https://abcdefghijk.supabase.co`.
   2. Click **Project Settings** (the gear icon near the bottom of the sidebar), then **API Keys**. Open the **Legacy API keys** tab and copy the **anon public** key. It is a long string that starts with `eyJ`.
   3. Keep both somewhere handy. You will paste them into the app in section 4.

> Use the **anon public** key from the **Legacy API keys** tab. Do not use the newer **publishable** key here. Do not use the **service_role** (secret) key anywhere. It has full access to your data and must stay secret.

---

## 3. Put the app on GitHub Pages

GitHub Pages turns a folder of files into a live web address, free of charge.

You need a GitHub account (sign up at **github.com** if you do not have one).

### Option A: upload in your browser (easiest)

1. Sign in to GitHub and click the **+** at the top right, then **New repository**.
2. Name it, for example `duo-budget`.
3. Choose **Public**. (Private also works on a paid GitHub plan.)
4. Click **Create repository**.
5. On the new repository page, click **Add file → Upload files**.
6. Drag in `index.html` and `.nojekyll` from the Duo folder. Make sure `.nojekyll` is included; it is a hidden file, so check the list after the upload.
7. You can also add `README.md` and `supabase.sql`. The app itself only needs `index.html` and `.nojekyll`.
8. Scroll down, click **Commit changes**.
9. Turn on the website:
   1. Click **Settings** (the tab on the repository page).
   2. In the left sidebar, click **Pages**.
   3. Under **Build and deployment**, set **Source** to **Deploy from a branch**.
   4. Under **Branch**, choose **main** and **/ (root)**, then click **Save**.
10. Wait 1 to 2 minutes, then refresh the Pages screen. It will show your live address:
    `https://<username>.github.io/<repo>/`
    Replace `<username>` with your GitHub username and `<repo>` with the repository name.

### Option B: use git in a terminal (if you are comfortable with it)

```bash
cd ~/Documents/Duo-Budget
git init -b main
git add index.html .nojekyll README.md supabase.sql
git commit -m "Duo budget app"
git remote add origin https://github.com/<username>/<repo>.git
git push -u origin main
```

Then enable Pages exactly as in step 9 of Option A. Replace `<username>` and `<repo>` with your own details; the repository must already exist on GitHub (create it with the **New repository** button first).

Open your live address once it is ready. You should see the Duo setup screen.

### Updating the app later

When a new version of `index.html` is ready, put it on GitHub again. Your data is not affected.

- **In the browser:** open your repository, click **Add file → Upload files**, drag in the new `index.html`, then click **Commit changes**. The new file replaces the old one. Wait a minute or two, then reload Duo.
- **With git:**

```bash
cd ~/Documents/Duo-Budget
git add index.html
git commit -m "Update Duo"
git push
```

If the database instructions ever change, you can run `supabase.sql` again in the SQL Editor. Running it again is safe.

---

## 4. First run: pairing the two of you

Each of you uses your own phone, and you go through these steps in order.

### Partner 1 (sets up the household)

Do this right after you run the SQL script in section 2. The first person to create the household becomes its owner.

1. Open your Duo address in the browser.
2. On the first screen, paste the **Project URL** and the **anon public** key from section 2, step 6. Tap **Continue**.
3. Create your account: enter your email and a password of at least 8 characters, then tap **Create account**.
   - If you turned on "Confirm email", open the email on this same phone and browser, click the link, then come back and sign in.
4. Create the household:
   1. Enter your name.
   2. Choose a **household passphrase**. This is the shared key that lets your partner join. Use four or more random words, for example `maple river candle seven`. It must be at least 8 characters. Random words are much harder to guess than a name or a date.
   3. Type it again to confirm.
   4. Choose your currency.
   5. Tap **Create household**.
5. Share the household passphrase with your partner **privately**, in person or in a private message only the two of you can read. Do not share it in the app, and do not post it anywhere public.

### Partner 2 (joins)

1. Open the **same** Duo address on your own phone.
2. Paste the **same** Project URL and anon public key. Tap **Continue**.
3. Create **your own** account with your own email and password.
4. Duo will show a **Join household** screen automatically, because a household already exists. Enter your name and the household passphrase your partner shared with you.
5. Tap **Join**. You will now see the same household as your partner.

Each of you has your own login. The app tells you which partner you are, so spending is recorded under the right name.

### Lock the door (once you have both joined)

Once you both have accounts, turn off new sign-ups so nobody else can create an account on your project. Do this only after your partner has joined, because once it is off, nobody new can sign up.

1. In Supabase, click **Authentication**, then **Sign In / Providers**.
2. Find **Allow new users to sign up** and switch it **off**.

You can both keep signing in as normal. If one of you ever needs a new account, you can turn sign-ups back on for a moment, create the account, and then switch it off again.

---

## 5. Add Duo to your Home Screen

Adding Duo to your Home Screen gives you an icon that opens it full screen, like an app.

**iPhone (Safari)**

1. Open your Duo address in **Safari**. (This must be Safari, not Chrome.)
2. Tap the **Share** button (the square with an arrow pointing up).
3. Scroll down and tap **Add to Home Screen**.
4. Tap **Add** in the top right.

> On iPhone, the app you add to the Home Screen keeps its own sign-in, separate from Safari. Even if you are already signed in in Safari, sign in once inside the installed app.

**Android (Chrome)**

1. Open your Duo address in **Chrome**.
2. Tap the **⋮** menu at the top right.
3. Tap **Add to Home screen**, or **Install app**, depending on your phone.
4. Confirm the name, then tap **Add** or **Install**.

---

## 6. Security notes

- **The anon public key is safe to paste into the app.** It is designed to be used in a browser. Your data is protected by rules in the database that only let the two members of your household read and change it.
- **Keep the household passphrase private.** Anyone who has it can try to join. The app only allows two people in total, and it limits wrong guesses to 5 per account and 20 overall in any 15 minutes. Do not post it in chat groups, emails or screenshots.
- **Everything is recorded.** The database stamps who added, changed, or deleted every expense and income, so you can always see who did what.
- **Never share or commit the service_role key.** Keep it out of GitHub and out of this app entirely. You do not need it.
- **Your passwords are your own.** Each of you signs in with your own email and password. Choose a password you do not use anywhere else.
- **Deleting is soft.** Removing an expense or income hides it and leaves a record. You can restore it from **Activity → History** at any time.

---

## 7. Troubleshooting

| What you see | What to do |
|---|---|
| "Setup says the database isn't ready" | The `supabase.sql` script has not been run yet. Follow section 2, step 3, then reload Duo. |
| "Invalid API key" | You copied the wrong key. Go to **Project Settings → API Keys**, open the **Legacy API keys** tab, and copy the **anon public** key again. Make sure you did not copy the Project URL by mistake, and never the **service_role** key. |
| "Check your email" never arrives | Check your spam or junk folder first. If it still does not come, go to **Authentication → Sign In / Providers → Email** in Supabase and switch off **Confirm email** (see section 2, step 4). |
| "That link has expired" | Links only work for a short time. Request a new reset link and use the newest email, not an older one. |
| Changes don't appear on the other phone | Open Supabase, go to **Database → Publications**, and check that realtime is on for the tables `expenses`, `incomes`, `budgets`, `household` and `members`. If anything is missing, run `supabase.sql` again in the SQL Editor. Then close and reopen Duo. |
| "This household already has two people" | Only two partners can share a household. If you are one of them, sign in with your own account. If you are not, you need to create a new Supabase project for a different household. |
| "Too many attempts" | The join is limited to 5 tries per account, and 20 across everyone, every 15 minutes. Wait 15 minutes and try again with the correct passphrase. |
| "Sign-ups are disabled" | Someone has switched off new sign-ups. If one of you needs a new account, switch **Allow new users to sign up** back on for a moment, following **Lock the door** in section 4, then switch it off again. |
| I opened the app at `…/index.html` and email links don't work | Use the address that ends in `/<repo>/`, without `index.html`, for example `https://<username>.github.io/<repo>/`. Then request the link again. |
| Duo stops loading and the database is unreachable | Your free Supabase project may be paused. See section 8. |
| Need to point Duo at a different database | In Duo, go to **Settings → Database → Change database**, then paste the new Project URL and anon key. |

---

## 8. Free-tier notes

- Supabase's free plan **pauses projects that have been inactive for about 7 days**. A paused project cannot load your data.
- To wake it up, sign in to **supabase.com**, open your project's dashboard, and wait for it to resume. Then reload Duo.
- Your data is kept while the project is paused. Nothing is lost.

---

## 9. Coming later: email (not built yet)

**Coming later.** Duo could one day learn about spending from your email, such as receipts and order confirmations, and about upcoming bills, such as utility or phone statements with due dates.

The idea in plain language:

- You set up an address (a forwarding inbox) and create a rule in your email app to forward receipts and bills to it.
- A small helper service reads each forwarded email and picks out the amount, the shop or company, and the date.
- Nothing is added automatically. Each item appears in an **Inbox** in Duo as "pending", and one of you taps **Approve** to turn it into an expense, or marks a bill to appear under **Upcoming bills** on the Home screen.

Why this approach: it works with any email provider, Duo never gets your email password, and only the mail you choose to forward is ever seen.

What it would need:

- A domain name (for example through Cloudflare, about €10 a year), or a forwarding address from an inbound email service.
- An API key for an AI model, stored safely as a secret in Supabase. Each email costs only a fraction of a cent to process.
- New sections of the database for the inbox and bills. These would follow the same privacy rules as everything else.

Bank feeds are another option for later. They are the most accurate for what you have actually spent, while email is better for bills you have not paid yet.

None of this is part of the current app. Everything above is a plan for later.

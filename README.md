# TaskFlow

**পরিকল্পনা করুন, টিমের সঙ্গে কাজ করুন, অগ্রগতি ট্র্যাক করুন।**

TaskFlow একটি full-stack project ও task management অ্যাপ। এতে project তৈরি, task assign, deadline ও priority নির্ধারণ, Kanban board-এ কাজের অবস্থা দেখা এবং টিমের সঙ্গে আলোচনা করা যায়। এটি CodeAlpha Full Stack Development Internship-এর Task 3 হিসেবে তৈরি।

## ফিচার

- Dashboard-এ project ও task-এর সারাংশ, অগ্রগতি, deadline এবং overdue কাজ দেখা।
- Project ও task তৈরি, সম্পাদনা, মুছে ফেলা এবং team member-দের কাজ assign করা।
- **To Do → In Progress → In Review → Completed** Kanban board-এ drag-and-drop করে task সরানো।
- Search ও filter-সহ task list ব্যবহার করা।
- Comment, notification, priority, due date এবং label দিয়ে কাজের সমন্বয় করা।
- Profile, project membership এবং role-ভিত্তিক access পরিচালনা করা।
- Responsive interface-এ light ও dark theme ব্যবহার করা।

## প্রযুক্তি

| অংশ | প্রযুক্তি |
| --- | --- |
| Frontend | React 19, TypeScript, Vite, Tailwind CSS 4 |
| UI ও state | Zustand, Motion, Lucide React, React Hot Toast |
| Backend | Node.js, Express, TypeScript |
| Authentication | Better Auth |
| Database | MongoDB Native Driver ও Better Auth MongoDB adapter |

## লোকালি চালানোর সম্পূর্ণ নির্দেশনা

### ১. যা আগে লাগবে

- Node.js **20.19+** অথবা **22.12+** এবং npm।
- MongoDB চলমান থাকতে হবে—নিজের কম্পিউটারে local MongoDB অথবা MongoDB Atlas।
- এই repository-র `Frontend/` ফোল্ডারে অ্যাপের source code ও `package.json` আছে।

Node.js/npm ইনস্টল আছে কি না যাচাই করুন:

```bash
node --version
npm --version
```

### ২. অ্যাপের ফোল্ডারে যান এবং dependency ইনস্টল করুন

Repository root থেকে:

```bash
cd Frontend
npm install
```

### ৩. MongoDB প্রস্তুত করুন

**Local MongoDB:** MongoDB server ইনস্টল ও চালু করুন। ডিফল্ট local connection string হলো `mongodb://127.0.0.1:27017`। Windows-এ MongoDB service চালু আছে কি না Services অ্যাপ থেকে দেখুন; Linux/macOS-এ আপনার MongoDB installation অনুযায়ী service চালু করুন।

**MongoDB Atlas:** Atlas-এ একটি database cluster তৈরি করে connection string নিন। Atlas Network Access-এ আপনার IP অনুমোদন করুন এবং database user-এর username/password দিন। Connection string-এ password-এর বিশেষ অক্ষর URL-encode করতে হতে পারে। Atlas সাধারণত replica set ব্যবহার করে।

### ৪. Environment file তৈরি করুন

`Frontend/` ফোল্ডারের ভেতরে `.env.example` কপি করে `.env` বানান:

**Windows PowerShell:**

```powershell
Copy-Item .env.example .env
```

**macOS/Linux:**

```bash
cp .env.example .env
```

এবার `.env` ফাইল খুলে এই মানগুলো দিন:

```dotenv
PORT=3000
NODE_ENV=development
BETTER_AUTH_URL=http://localhost:3000
BETTER_AUTH_SECRET=এখানে-একটি-দীর্ঘ-এবং-অনন্য-secret-দিন
MONGODB_URI=mongodb://127.0.0.1:27017
MONGODB_DB_NAME=taskflow_db
MONGODB_REPLICA_SET=false
```

`BETTER_AUTH_SECRET`-এ নিজের secret ব্যবহার করুন; চাইলে Node.js দিয়ে একটি তৈরি করতে পারেন:

```bash
node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"
```

Atlas হলে `MONGODB_URI`-তে Atlas connection string দিন এবং `MONGODB_REPLICA_SET=true` করুন। Local standalone MongoDB হলে `MONGODB_REPLICA_SET=false` রাখুন। `BETTER_AUTH_SECRET` না থাকলে server চালু হবে না। `.env`-এ password ও secret থাকে—এটি GitHub-এ commit করবেন না; `.gitignore` এটি বাদ রাখে।

### ৫. Development server চালু করুন

কমান্ডটি `Frontend/` ফোল্ডার থেকে চালান:

```bash
npm run dev
```

Terminal-এ MongoDB connection সফল হওয়ার বার্তা এলে browser-এ [http://localhost:3000](http://localhost:3000) খুলুন। Frontend এবং Express API একই server/origin-এ চলে; আলাদা frontend বা backend চালানোর দরকার নেই। নতুন database-এ শুরুতে কোনো project বা task থাকে না—অ্যাকাউন্ট তৈরি করে project বানিয়ে শুরু করুন।

চালু server বন্ধ করতে terminal-এ **Ctrl+C** চাপুন। `PORT` বদলালে browser-এ সেই port ব্যবহার করুন, যেমন `PORT=4000` হলে `http://localhost:4000`।

### ৬. Test, type-check ও production build

সব কমান্ড `Frontend/` ফোল্ডার থেকে চালাতে হবে:

```bash
npm test       # টেস্ট চালায়
npm run lint   # TypeScript type-check
npm run build  # production frontend ও server build
npm start      # production server চালায় (আগে build করতে হবে)
npm run clean  # তৈরি হওয়া build output মুছে দেয়
```

Production-এও MongoDB এবং `.env`-এর প্রয়োজনীয় environment variable দিতে হবে। `NODE_ENV=production` সেট করুন। `npm run build`-এর পর `npm start` চালালে server নির্ধারিত `PORT`-এ (না দিলে 3000) frontend ও API পরিবেশন করবে।

## সাধারণ সমস্যা

| সমস্যা | কী দেখবেন |
| --- | --- |
| `MONGODB_URI is required` | `Frontend/.env` তৈরি হয়েছে এবং `MONGODB_URI` সেট আছে কি না দেখুন। |
| MongoDB connection failed | MongoDB service চলছে কি না, URI ও credentials সঠিক কি না, Atlas হলে IP allowlist-এ আছে কি না দেখুন। |
| `BETTER_AUTH_SECRET` সংক্রান্ত error | `.env`-এ `BETTER_AUTH_SECRET` বা `AUTH_SECRET` সেট করুন। |
| Port আগে থেকেই ব্যবহৃত | `.env`-এ অন্য `PORT` দিন অথবা ওই port ব্যবহারকারী process বন্ধ করুন। |
| `.env` পরিবর্তনের পরও কাজ হচ্ছে না | Development server বন্ধ করে আবার `npm run dev` চালান। |

## Repository কাঠামো

```text
.
├── README.md
└── Frontend/
    ├── server.ts             # Express server ও API setup
    ├── server/               # Database, auth, permissions ও API routes
    ├── src/
    │   ├── components/       # React views ও UI components
    │   ├── lib/              # API client ও auth helpers
    │   ├── store/            # Zustand application state
    │   └── types/            # TypeScript types
    ├── scripts/              # Dev server ও test runner
    ├── .env.example          # Environment variable নমুনা
    └── package.json          # App scripts ও dependencies
```

## API overview

API একই origin-এ `/api` path-এর অধীনে চলে। প্রধান route-গুলো:

| Route | কাজ |
| --- | --- |
| `/api/auth` | Sign in, sign up ও profile |
| `/api/projects` | Project ও membership |
| `/api/tasks` | Task তৈরি, filter, update ও delete |
| `/api/comments` | Task discussion |
| `/api/notifications` | Notification ও read status |
| `/api/dashboard/stats` | Dashboard metrics |
| `/api/health` | Server health check |

## বর্তমান অবস্থা ও সীমাবদ্ধতা

এটি internship project। বর্তমান access model-এ project role-এর পাশাপাশি legacy global admin role-ও আছে। Project-এ member সরাসরি যোগ করা হয়; invitation গ্রহণ/প্রত্যাখ্যানের workflow নেই। বাস্তব production team-এ ব্যবহারের আগে authorization model পর্যালোচনা ও প্রয়োজন অনুযায়ী পরিবর্তন করুন।

## License

Repository-তে বর্তমানে license file নেই। পুনর্বিতরণ বা অন্য কাজে ব্যবহারের আগে project owner-এর সঙ্গে যোগাযোগ করুন।

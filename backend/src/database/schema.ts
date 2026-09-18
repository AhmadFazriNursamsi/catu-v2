import { pgTable, serial, integer, varchar, text, boolean, timestamp } from 'drizzle-orm/pg-core';

export const roles = pgTable('roles', {
  id: serial('id').primaryKey(),
  code: varchar('code', { length: 50 }).notNull().unique(),
  name: varchar('name', { length: 100 }).notNull(),
  description: text('description'),
  createdAt: timestamp('created_at').defaultNow(),
});

export const authUsers = pgTable('auth_users', {
  id: serial('id').primaryKey(),
  username: varchar('username', { length: 100 }),
  passwordHash: varchar('password_hash', { length: 255 }),
  phoneNumber: varchar('phone_number', { length: 50 }).notNull().unique(),
  email: varchar('email', { length: 100 }),
  roleId: integer('role_id').references(() => roles.id),
  accountStatus: varchar('account_status', { length: 50 }).default('APPROVED'),
  fcmToken: text('fcm_token'),
  lastLogin: timestamp('last_login'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

export const keuskupan = pgTable('keuskupan', {
  id: integer('id').primaryKey(),
  name: varchar('name', { length: 255 }).notNull(),
});

export const paroki = pgTable('paroki', {
  id: integer('id').primaryKey(),
  name: varchar('name', { length: 255 }).notNull(),
  keuskupanId: integer('keuskupan_id').references(() => keuskupan.id),
});

export const wilayah = pgTable('wilayah', {
  id: integer('id').primaryKey(),
  parokiId: integer('paroki_id').references(() => paroki.id),
  name: varchar('name', { length: 255 }).notNull(),
});

export const lingkungan = pgTable('lingkungan', {
  id: integer('id').primaryKey(),
  wilayahId: integer('wilayah_id').references(() => wilayah.id),
  name: varchar('name', { length: 255 }).notNull(),
});

export const ordo = pgTable('ordo', {
  id: integer('id').primaryKey(),
  code: varchar('code', { length: 50 }).notNull(),
  name: varchar('name', { length: 255 }).notNull(),
});

export const masterPositions = pgTable('master_positions', {
  id: serial('id').primaryKey(),
  category: varchar('category', { length: 50 }).notNull(),
  code: varchar('code', { length: 50 }).notNull().unique(),
  name: varchar('name', { length: 100 }).notNull(),
  isLead: boolean('is_lead').default(false),
  createdAt: timestamp('created_at').defaultNow(),
});

export const userProfiles = pgTable('user_profiles', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').references(() => authUsers.id).notNull(),
  fullName: varchar('full_name', { length: 255 }).notNull(),
  phoneNumber: varchar('phone_number', { length: 50 }),
  email: varchar('email', { length: 100 }),
  keuskupanId: integer('keuskupan_id'),
  parokiId: integer('paroki_id'),
  wilayahId: integer('wilayah_id'),
  lingkunganId: integer('lingkungan_id'),
  ordoId: integer('ordo_id'),
  pengurusPosition: varchar('pengurus_position', { length: 100 }),
  romoPosition: varchar('romo_position', { length: 100 }),
  jabatanStartYear: integer('jabatan_start_year'),
  jabatanEndYear: integer('jabatan_end_year'),
  jabatanStartDate: varchar('jabatan_start_date', { length: 20 }),
  jabatanEndDate: varchar('jabatan_end_date', { length: 20 }),
  isJabatanActive: boolean('is_jabatan_active').default(false),
  birthDate: varchar('birth_date', { length: 20 }),
  address: text('address'),
  avatarUrl: text('avatar_url'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

export const serviceCategories = pgTable('service_categories', {
  id: serial('id').primaryKey(),
  name: varchar('name', { length: 100 }).notNull(),
  description: text('description'),
  isUrgentDefault: boolean('is_urgent_default').default(false),
  isActive: boolean('is_active').default(true),
  createdAt: timestamp('created_at').defaultNow(),
});

export const urgencyLevels = pgTable('urgency_levels', {
  id: serial('id').primaryKey(),
  code: varchar('code', { length: 50 }).notNull(),
  name: varchar('name', { length: 100 }).notNull(),
  hoursThreshold: integer('hours_threshold').notNull(),
});

export const orders = pgTable('orders', {
  id: serial('id').primaryKey(),
  orderNumber: varchar('order_number', { length: 50 }).notNull().unique(),
  userId: integer('user_id').references(() => authUsers.id).notNull(),
  categoryId: integer('category_id').references(() => serviceCategories.id).notNull(),
  status: varchar('status', { length: 50 }).default('PENDING'),
  locationName: text('location_name'),
  locationAddress: text('location_address'),
  locationLatitude: varchar('location_latitude', { length: 50 }),
  locationLongitude: varchar('location_longitude', { length: 50 }),
  scheduledDate: varchar('scheduled_date', { length: 50 }),
  scheduledTime: varchar('scheduled_time', { length: 50 }),
  notes: text('notes'),
  attachmentUrl: text('attachment_url'),
  acceptedRomoId: integer('accepted_romo_id'),
  parokiId: integer('paroki_id'),
  lingkunganId: integer('lingkungan_id'),
  keuskupanId: integer('keuskupan_id'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

export const orderItems = pgTable('order_items', {
  id: serial('id').primaryKey(),
  orderId: integer('order_id').references(() => orders.id).notNull(),
  scheduledDate: varchar('scheduled_date', { length: 50 }),
  scheduledTime: varchar('scheduled_time', { length: 50 }),
  notes: text('notes'),
  createdAt: timestamp('created_at').defaultNow(),
});

export const orderReschedules = pgTable('order_reschedules', {
  id: serial('id').primaryKey(),
  orderId: integer('order_id').references(() => orders.id).notNull(),
  itemId: integer('item_id'),
  proposedBy: integer('proposed_by').references(() => authUsers.id).notNull(),
  previousDate: varchar('previous_date', { length: 50 }),
  previousTimeStart: varchar('previous_time_start', { length: 50 }),
  previousTimeEnd: varchar('previous_time_end', { length: 50 }),
  proposedDate: varchar('proposed_date', { length: 50 }).notNull(),
  proposedTimeStart: varchar('proposed_time_start', { length: 50 }).notNull(),
  proposedTimeEnd: varchar('proposed_time_end', { length: 50 }),
  reason: text('reason').notNull(),
  status: varchar('status', { length: 50 }).default('PENDING_UMAT'),
  respondedBy: integer('responded_by').references(() => authUsers.id),
  respondedAt: timestamp('responded_at'),
  createdAt: timestamp('created_at').defaultNow(),
});

export const orderRomoHandovers = pgTable('order_romo_handovers', {
  id: serial('id').primaryKey(),
  orderId: integer('order_id').references(() => orders.id).notNull(),
  itemId: integer('item_id'),
  previousRomoId: integer('previous_romo_id').references(() => authUsers.id).notNull(),
  newRomoId: integer('new_romo_id').references(() => authUsers.id),
  handoverType: varchar('handover_type', { length: 50 }).notNull(),
  reason: text('reason').notNull(),
  status: varchar('status', { length: 50 }).default('COMPLETED'),
  createdAt: timestamp('created_at').defaultNow(),
  respondedAt: timestamp('responded_at'),
});

export const chatGroups = pgTable('chat_groups', {
  id: serial('id').primaryKey(),
  orderId: integer('order_id').references(() => orders.id),
  name: varchar('name', { length: 255 }),
  createdAt: timestamp('created_at').defaultNow(),
});

export const chatGroupMembers = pgTable('chat_group_members', {
  id: serial('id').primaryKey(),
  chatGroupId: integer('chat_group_id').references(() => chatGroups.id).notNull(),
  userId: integer('user_id').references(() => authUsers.id).notNull(),
  roleInGroup: varchar('role_in_group', { length: 50 }).default('MEMBER'),
  lastReadMessageId: integer('last_read_message_id'),
  joinedAt: timestamp('joined_at').defaultNow(),
});

export const chatMessages = pgTable('chat_messages', {
  id: serial('id').primaryKey(),
  chatGroupId: integer('chat_group_id').references(() => chatGroups.id).notNull(),
  senderId: integer('sender_id').references(() => authUsers.id),
  messageType: varchar('message_type', { length: 50 }).default('TEXT'),
  message: text('message').notNull(),
  attachmentUrl: text('attachment_url'),
  replyToMessageId: integer('reply_to_message_id'),
  createdAt: timestamp('created_at').defaultNow(),
});

export const notifications = pgTable('notifications', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').references(() => authUsers.id).notNull(),
  title: varchar('title', { length: 255 }).notNull(),
  body: text('body').notNull(),
  data: text('data'),
  isRead: boolean('is_read').default(false),
  createdAt: timestamp('created_at').defaultNow(),
});

export const news = pgTable('news', {
  id: serial('id').primaryKey(),
  title: varchar('title', { length: 255 }).notNull(),
  content: text('content'),
  imageUrl: text('image_url'),
  sourceUrl: text('source_url'),
  publishedAt: timestamp('published_at'),
  createdAt: timestamp('created_at').defaultNow(),
});

export const apks = pgTable('apks', {
  id: serial('id').primaryKey(),
  versionName: varchar('version_name', { length: 50 }).notNull(),
  versionCode: integer('version_code').notNull(),
  downloadUrl: text('download_url').notNull(),
  fileSizeBytes: integer('file_size_bytes'),
  isActive: boolean('is_active').default(true),
  createdAt: timestamp('created_at').defaultNow(),
});

export const activityLogs = pgTable('activity_logs', {
  id: serial('id').primaryKey(),
  userId: integer('user_id').references(() => authUsers.id),
  userName: varchar('user_name', { length: 255 }),
  userRole: varchar('user_role', { length: 50 }),
  action: varchar('action', { length: 100 }).notNull(),
  targetEntity: varchar('target_entity', { length: 50 }),
  targetId: varchar('target_id', { length: 100 }),
  description: text('description').notNull(),
  ipAddress: varchar('ip_address', { length: 50 }),
  userAgent: text('user_agent'),
  metadata: text('metadata'),
  createdAt: timestamp('created_at').defaultNow(),
});

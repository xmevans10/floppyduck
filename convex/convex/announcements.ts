import { internalMutation, query } from "./_generated/server";
import { v } from "convex/values";

export const getActive = query({
  args: {
    deviceId: v.optional(v.string()),
    sessionToken: v.optional(v.string()),
  },
  handler: async (ctx) => {
    const announcements = await ctx.db
      .query("announcements")
      .withIndex("by_active_createdAt", (q) =>
        q.eq("active", true),
      )
      .order("desc")
      .collect();

    return announcements.map((a) => ({
      id: a._id,
      title: a.title,
      body: a.body,
      color: a.color ?? "#4CAF50",
    }));
  },
});

export const create = internalMutation({
  args: {
    title: v.string(),
    body: v.array(v.string()),
    color: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    await ctx.db.insert("announcements", {
      title: args.title,
      body: args.body,
      color: args.color,
      active: true,
      createdAt: Date.now(),
    });
  },
});

export const deactivateAll = internalMutation({
  args: {},
  handler: async (ctx) => {
    const all = await ctx.db.query("announcements").collect();
    for (const a of all) {
      await ctx.db.patch(a._id, { active: false });
    }
  },
});

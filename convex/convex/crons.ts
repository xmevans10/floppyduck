import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

crons.interval("cleanup", { minutes: 1 }, internal.cleanup.run);

export default crons;

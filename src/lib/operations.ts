import {db} from "./supabase";
function client(){if(!db)throw new Error("Supabase not configured");return db}
export async function listOrganizations(){const {data,error}=await client().from("organizations").select("id,name");if(error)throw error;return data}
export async function listProperties(organizationId:string){const {data,error}=await client().from("properties").select("id,name,address").eq("organization_id",organizationId);if(error)throw error;return data}
export async function listWorkOrders(organizationId:string){const {data,error}=await client().from("work_orders").select("id,title,status,priority,property_id").eq("organization_id",organizationId);if(error)throw error;return data}
export async function createWorkOrder(organizationId:string,propertyId:string,title:string){const api=client();const {data:{user}}=await api.auth.getUser();if(!user)throw new Error("Sign in required");const {data,error}=await api.from("work_orders").insert({organization_id:organizationId,property_id:propertyId,title,created_by:user.id}).select("id").single();if(error)throw error;return data}

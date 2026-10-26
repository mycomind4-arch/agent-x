import App from "./App";
import ConnectedApp from "./ConnectedApp";
import {db} from "./lib/supabase";
export default function Entry(){return db?<ConnectedApp/>:<App/>}

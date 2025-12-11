import React, { useEffect, useState } from "react";
import axios from "axios";

function App() {
  const [users, setUsers] = useState([]);
  const [form, setForm] = useState({ name: "", email: "" });

  const BACKEND = "http://13.205.15.98:4000";

  useEffect(() => {
    axios.get(`${BACKEND}/users`).then(res => setUsers(res.data));
  }, []);

  const submit = () => {
    axios.post(`${BACKEND}/users`, form).then(() => {
      alert("User Added");
      window.location.reload();
    });
  };

  return (
    <div style={{ padding: 20 }}>
      <h2>DevOps Full-Stack Demo</h2>

      <input placeholder="Name"
        onChange={e => setForm({ ...form, name: e.target.value })} />

      <input placeholder="Email"
        onChange={e => setForm({ ...form, email: e.target.value })} />

      <button onClick={submit}>Add User</button>

      <h3>User List</h3>
      {users.map(u => (
        <p key={u.id}>{u.name} - {u.email}</p>
      ))}
    </div>
  );
}

export default App;

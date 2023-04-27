import { BrowserRouter, Routes, Route } from "react-router-dom";
import Layout from "./Layout";
import ObuitaryForm from "./ObuitaryForm.js";

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Layout />}>
          <Route path="/create" element={<ObuitaryForm/>}></Route>
        </Route>
      </Routes>
    </BrowserRouter>
  )
}

export default App;
import { Outlet, useNavigate } from "react-router-dom";
import { useState, useEffect } from "react";
import Ob from "./Ob"
import axios from "axios";
const Layout = () => {
    const [ obs, setObs ] = useState([]);
    const [ id, setId ] = useState();
    const [ loading, setLoading] = useState(false);
    const [ populated, setPopulated ] = useState(true);
    const navigate = useNavigate();
    
    useEffect(() => {
        setLoading(true);
        console.log(obs);
        const fetch = async () => {
            try {
                const response = await axios.get('https://regpx2wuh7hpfjbbbrjl4h2egu0knydt.lambda-url.ca-central-1.on.aws');
                console.log(response);
                const data = JSON.stringify(response.data);
                setObs(JSON.parse(data));
            } catch (error) {
                console.log(error);
            } finally {
                console.log(obs.length);
                if (!(obs.length > 0)) {
                    setPopulated(false);
                }
                setLoading(false);
            }
        }
        fetch();
    }, []);

    useEffect(() => {
        console.log(obs);
        if (obs.length > 0) {
            setPopulated(true);
        } else {
            setPopulated(false);
        }
    }, [obs]);

    function newOb() {
        if (obs.length > 0) {
            setId(obs.length + 1);
        } else {
            setId(1);
        }
        console.log(id);
        navigate('/create');
    }
    return (
        <>
            <div id= "title">
                
                <h1>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</h1> 
                <h1>The Last Show</h1>
                <div id = "new-ob" onClick={newOb}>
                    <label>+ New Obituary</label>
                </div>
            </div>
            <div className="content">
                <Outlet context={[[obs, setObs], [id, setId], [populated, setPopulated]]}/>
            </div>
            <div className="obituaries">
                {
                    loading ? <div class="lds-ring"><div></div><div></div><div></div><div></div></div> :
                    !populated ? <div className="NA">No Obituary Yet</div> :
                    <>
                        <div className="col1">
                           {obs.map((ob, index) => (
                            index % 4 == 0 ? 
                            <Ob
                                newOb = {id}
                                id = {ob.id}
                                name = {ob.name}
                                born = {ob.born_year}
                                died = {ob.died_year}
                                image_url = {ob.image_url}
                                obituary = {ob.obituary}
                                speech_url = {ob.speech_url}
                            /> : <></>
                           ))} 
                        </div>
                        <div className="col2">
                            {obs.map((ob, index) => (
                            index % 4 == 1 ? 
                            <Ob
                                newOb = {id}
                                id = {ob.id}
                                name = {ob.name}
                                born = {ob.born_year}
                                died = {ob.died_year}
                                image_url = {ob.image_url}
                                obituary = {ob.obituary}
                                speech_url = {ob.speech_url}
                            /> : <></>
                           ))}
                        </div>
                        <div className="col3">
                            {obs.map((ob, index) => (
                            index % 4 == 2 ? 
                            <Ob
                                newOb = {id}
                                id = {ob.id}
                                name = {ob.name}
                                born = {ob.born_year}
                                died = {ob.died_year}
                                image_url = {ob.image_url}
                                obituary = {ob.obituary}
                                speech_url = {ob.speech_url}
                            /> : <></>
                           ))}
                        </div>
                        <div className="col4">
                            {obs.map((ob, index) => (
                            index % 4 == 3 ? 
                            <Ob
                                newOb = {id}
                                id = {ob.id}
                                name = {ob.name}
                                born = {ob.born_year}
                                died = {ob.died_year}
                                image_url = {ob.image_url}
                                obituary = {ob.obituary}
                                speech_url = {ob.speech_url}
                            /> : <></>
                           ))}
                        </div>
                    </>
                }
            </div>
        </> 
     );
}
 
export default Layout;
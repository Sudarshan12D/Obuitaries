import { useState, useEffect } from "react";
const Ob = ({ newOb, id, name, born, died, image_url, obituary, speech_url }) => {
    const [selected, setSelected] = useState(() => {
        if (newOb == id) {
            return true;
        } else {
            return false;
        }
    });
    const [symbol, setSymbol] = useState("&#9654;");
    const [audio, setAudio] = useState(new Audio(speech_url));
    useEffect(() => {
        audio.load();
        audio.onended = () => {
            setSymbol("&#9654;");
        }

    }, []);
    const handleClick = () => {
        console.log(audio.paused);
        if (audio.paused) {
            audio.play();
            setSymbol("&#10074;&#10074;");
        } else {
            audio.pause();
            setSymbol("&#9654;");
        }
    }
    const handleImgClick = () => {
        setSelected(!selected);
    }
    return ( 
        <div className="obHolder">
            <img className="obPic" src={ image_url } onClick={ handleImgClick }></img>
            <h2 className="obName">{ name }</h2>
            <h4 className="obLife">{ born } - { died }</h4>
            {!selected ? <div></div> :
            <>
                <h6 className="obOb"> { obituary } </h6>
                <button className="audioPlayer" onClick={ handleClick }>
                    <span dangerouslySetInnerHTML={ {__html: symbol} }></span>
                </button>
            </>
            }

        </div>
        

     );
}
 
export default Ob;
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/codegangsta/negroni"
	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/mux"
	alexa "github.com/waringer/go-alexa/skillserver"
)

func main() {
	ConfFile := flag.String("c", "radio.conf", "config file to use")
	Version := flag.Bool("v", false, "prints current version and exit")
	flag.Parse()

	if *Version {
		fmt.Println("Build:", buildstamp)
		fmt.Println("Githash:", githash)
		os.Exit(0)
	}

	Config, err := loadConfig(*ConfFile)
	if err != nil {
		log.Println("can't read conf file", *ConfFile)
		saveConfig(Config, *ConfFile)
	}
	conf = Config

	if conf.AmazonAppID == "" {
		log.Fatalln("Amazon AppID fehlt!")
	}

	log.Printf("Alexa-Radio startet %s - %s", buildstamp, githash)

	if conf.PidFile != "" {
		writePid(conf.PidFile)
	}

	//check db
	db, err := openDB(conf)
	if err != nil {
		log.Fatalln("DB Fehler : ", err.Error())
	}
	defer db.Close()

	database = db

	var Applications = map[string]interface{}{
		"/echo/radio": alexa.EchoApplication{
			AppID:              conf.AmazonAppID,
			OnIntent:           radioHandler,
			OnLaunch:           radioHandler,
			OnSessionEnded:     infoHandler,
			OnAudioPlayerState: audioHandler,
			OnException:        infoHandler,
		},
	}

	runAlexa(Applications, conf.BindingIP, fmt.Sprintf("%d", conf.BindingPort))
}

func runAlexa(apps map[string]interface{}, ip, port string) {
	router := mux.NewRouter()
	alexa.Init(apps, router)

	n := negroni.Classic()
	n.UseHandler(router)
	n.Run(ip + ":" + port)
}

func audioHandler(echoReq *alexa.EchoRequest, echoResp *alexa.EchoResponse) {
	log.Printf("----> Audio Request Typ %s empfangen, UserID %s\n", echoReq.Request.Type, echoReq.Session.User.UserID)
	registerDevice(echoReq.Context.System.Device.DeviceId)

	switch echoReq.Request.Type {
	case "AudioPlayer.PlaybackStarted":
		log.Printf("type AudioPlayer.PlaybackStarted")
	case "AudioPlayer.PlaybackStopped":
		log.Printf("type AudioPlayer.PlaybackStopped")
	case "AudioPlayer.PlaybackFinished":
		log.Printf("type AudioPlayer.PlaybackFinished")
	case "AudioPlayer.PlaybackNearlyFinished":
		nextFileName := getNextFileName(echoReq.Context.System.Device.DeviceId)
		if nextFileName != "" {
			directive := makeAudioPlayDirective(nextFileName)
			log.Println("URL:", directive.AudioItem.Stream.Url)
			echoResp.Response.Directives = append(echoResp.Response.Directives, directive)
		}
		log.Printf("type AudioPlayer.PlaybackNearlyFinished")
	default:
		log.Printf("type unknown")
	}
}

func infoHandler(echoReq *alexa.EchoRequest, echoResp *alexa.EchoResponse) {
	log.Printf("----> Info Request Typ %s empfangen, UserID %s\n", echoReq.Request.Type, echoReq.Session.User.UserID)
	registerDevice(echoReq.Context.System.Device.DeviceId)
}

func radioHandler(echoReq *alexa.EchoRequest, echoResp *alexa.EchoResponse) {
	log.Printf("----> Request für Intent %s empfangen, UserID %s\n", echoReq.Request.Intent.Name, echoReq.Session.User.UserID)
	registerDevice(echoReq.Context.System.Device.DeviceId)

	switch echoReq.Request.Intent.Name {
	case "AMAZON.PauseIntent":
		Directive := alexa.EchoDirective{Type: "AudioPlayer.Stop"}
		echoResp.Response.Directives = append(echoResp.Response.Directives, Directive)
		log.Printf("pause intent")
	case "AMAZON.CancelIntent":
		log.Printf("cancel intent")
	case "AMAZON.StopIntent":
		Directive := alexa.EchoDirective{Type: "AudioPlayer.Stop"}
		echoResp.Response.Directives = append(echoResp.Response.Directives, Directive)
		log.Printf("stop intent")
	case "AMAZON.NextIntent":
		nextFileName := getNextFileName(echoReq.Context.System.Device.DeviceId)
		if nextFileName != "" {
			directive := makeAudioPlayDirective(nextFileName)
			log.Println("URL:", directive.AudioItem.Stream.Url)
			echoResp.Response.Directives = append(echoResp.Response.Directives, directive)
		}
	case "AMAZON.HelpIntent":
		log.Printf("help intent")
		fallthrough
	case "CurrentlyPlaying":
		log.Printf("CurrentlyPlaying intent")

		Artist, Album, Track := getPlayingInfo(echoReq.Context.System.Device.DeviceId)
		speech := fmt.Sprint(`<speak>`)
		card := ""

		if (Artist == "") && (Album == "") && (Track == "") {
			card = fmt.Sprint("Ich hab keinen plan was da laufen sollte, oder wieso!")
		} else {
			card = "Das sollte "

			if Track != "" {
				card += fmt.Sprintf(" %s ", Track)
			}
			if Artist != "" {
				card += fmt.Sprintf("von %s ", Artist)
			}
			if Album != "" {
				card += fmt.Sprintf("aus dem album %s ", Album)
			}

			card += " sein "
		}
		speech = fmt.Sprintf("%s%s</speak>", speech, card)

		//speech := fmt.Sprint(`<speak>`)
		//card := fmt.Sprint("Stör mich jetzt nicht, ich hab zu tun!")
		//speech = fmt.Sprintf("%s%s</speak>", speech, card)

		echoResp.OutputSpeechSSML(speech).Card("Network Music Player", card)
	case "AMAZON.ResumeIntent":
		log.Printf("resume intent")
		fallthrough
	case "ResumePlay":
		log.Printf("ResumePlay intent")
		nextFileName := getNextFileName(echoReq.Context.System.Device.DeviceId)
		if nextFileName != "" {
			directive := makeAudioPlayDirective(nextFileName)
			log.Println("URL:", directive.AudioItem.Stream.Url)

			speech := fmt.Sprint(`<speak>`)
			card := fmt.Sprint("Ok, ich mach ja schon weiter!")
			speech = fmt.Sprintf("%s%s</speak>", speech, card)

			echoResp.OutputSpeechSSML(speech).Card("Network Music Player", card)

			echoResp.Response.Directives = append(echoResp.Response.Directives, directive)
		} else {
			speech := fmt.Sprint(`<speak>`)
			card := fmt.Sprintf("Hey, erst musst du mir sagen was ich raussuchen muss! Also was soll es sein?")
			speech = fmt.Sprintf("%s%s</speak>", speech, card)

			echoResp.OutputSpeechSSML(speech).Card("Network Music Player", card)
			echoResp.Response.ShouldEndSession = false
		}
	case "StartPlay":
		log.Printf("StartPlay intent")
		SearchString := strings.TrimSpace(echoReq.Request.Intent.Slots["Searching"].Value)
		log.Println("====>", SearchString)

		if SearchString != "" {
			updateActualPlaying(echoReq.Context.System.Device.DeviceId, SearchString)
			nextFileName := getNextFileName(echoReq.Context.System.Device.DeviceId)
			if nextFileName != "" {
				directive := makeAudioPlayDirective(nextFileName)
				log.Println("URL:", directive.AudioItem.Stream.Url)

				speech := fmt.Sprint(`<speak>`)
				card := fmt.Sprintf("ich such ja schon %s raus", SearchString)
				speech = fmt.Sprintf("%s%s</speak>", speech, card)

				echoResp.OutputSpeechSSML(speech).Card("Network Music Player", card)

				echoResp.Response.Directives = append(echoResp.Response.Directives, directive)
			} else {
				speech := fmt.Sprint(`<speak>`)
				card := fmt.Sprintf("Ich konnte für %s absolut nix finden!", SearchString)
				speech = fmt.Sprintf("%s%s</speak>", speech, card)

				echoResp.OutputSpeechSSML(speech).Card("Network Music Player", card)
			}
		} else {
			goto AskUser
		}
		break
	AskUser:
		fallthrough
	default:
		fallthrough
	case "":
		log.Printf("default intent")

		speech := fmt.Sprint(`<speak>`)
		card := fmt.Sprint("Was willst du schon wieder?")
		speech = fmt.Sprintf("%s%s</speak>", speech, card)

		echoResp.OutputSpeechSSML(speech).Card("Network Music Player", card)
		echoResp.Response.ShouldEndSession = false
	}
}

func makeAudioPlayDirective(FileName string) alexa.EchoDirective {
	return alexa.EchoDirective{
		Type:         "AudioPlayer.Play",
		PlayBehavior: "REPLACE_ALL",
		AudioItem: &alexa.EchoAudioItem{
			Stream: alexa.EchoStream{
				Url:                  urlEncode(FileName),
				Token:                fmt.Sprintf("NMP-%s", time.Now().Format("20060102T150405999999")),
				OffsetInMilliseconds: 0}}}
}

func registerDevice(DeviceID string) {
	_, err := database.Exec("INSERT INTO DeVice (DV_id, DV_Alias, DV_LastActive) VALUES (?,null, CURRENT_TIMESTAMP) ON DUPLICATE KEY UPDATE DV_LastActive=CURRENT_TIMESTAMP;", DeviceID)
	if err != nil {
		log.Println("DB Error registerDevice:", err)
	}
}

func updateActualPlaying(DeviceID, Searching string) {
	_, err := database.Exec("CALL spUpdateActualPlaying(?,?);", DeviceID, Searching)
	if err != nil {
		log.Println("DB Error updateActualPlaying:", err)
	}
}

func getNextFileName(DeviceID string) (FileName string) {
	err := database.QueryRow("SELECT fnGetNextTrackFilename(?);", DeviceID).Scan(&FileName)
	if err != nil {
		log.Println("DB Error getNextFileName:", err)
	}

	return
}

func getPlayingInfo(DeviceID string) (Artist, Album, Trackname string) {
	err := database.QueryRow("SELECT AT_Name, AM_Name, TK_Name FROM vTrackInfo INNER JOIN DeVice ON DV_LastTKid = TK_id WHERE DV_id = ?;", DeviceID).Scan(&Artist, &Album, &Trackname)
	if err != nil {
		log.Println("DB Error getPlayingInfo:", err)
	}

	Artist = strings.TrimSpace(Artist)
	Album = strings.TrimSpace(Album)
	Trackname = strings.TrimSpace(Trackname)

	return
}

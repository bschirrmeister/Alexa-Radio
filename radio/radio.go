package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"../shared"

	"github.com/codegangsta/negroni"
	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/mux"
	alexa "github.com/waringer/go-alexa/skillserver"
)

var (
	buildstamp string
	githash    string
)

func main() {
	confFile := flag.String("c", "radio.conf", "config file to use")
	version := flag.Bool("v", false, "prints current version and exit")
	flag.Parse()

	if *version {
		fmt.Println("Build:", buildstamp)
		fmt.Println("Githash:", githash)
		os.Exit(0)
	}

	err := shared.LoadConfig(*confFile)
	if err != nil {
		log.Println("can't read conf file", *confFile)
		shared.SaveConfig(*confFile)
	}

	if shared.Conf.AmazonAppID == "" {
		log.Fatalln("Amazon AppID fehlt!")
	}

	log.Printf("Alexa-Radio startet %s - %s", buildstamp, githash)

	shared.WritePid()

	//check db
	err = shared.OpenDB()
	if err != nil {
		log.Fatalln("DB Fehler : ", err.Error())
	}
	defer shared.CloseDB()

	var Applications = map[string]interface{}{
		"/echo/radio": alexa.EchoApplication{
			AppID:              shared.Conf.AmazonAppID,
			OnIntent:           radioHandler,
			OnLaunch:           radioHandler,
			OnSessionEnded:     infoHandler,
			OnAudioPlayerState: audioHandler,
			OnException:        infoHandler,
		},
	}

	runAlexa(Applications, shared.Conf.BindingIP, fmt.Sprintf("%d", shared.Conf.BindingPort))
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
	shared.RegisterDevice(echoReq.Context.System.Device.DeviceId)

	switch echoReq.Request.Type {
	case "AudioPlayer.PlaybackStarted":
		log.Printf("type AudioPlayer.PlaybackStarted")
	case "AudioPlayer.PlaybackStopped":
		log.Printf("type AudioPlayer.PlaybackStopped")
	case "AudioPlayer.PlaybackFinished":
		log.Printf("type AudioPlayer.PlaybackFinished")
	case "AudioPlayer.PlaybackNearlyFinished":
		if !shared.ShouldStopPlaying(echoReq.Context.System.Device.DeviceId) {
			nextFileName := shared.GetNextFileName(echoReq.Context.System.Device.DeviceId)
			if nextFileName != "" {
				directive := makeAudioPlayDirective(nextFileName)
				log.Println("URL:", directive.AudioItem.Stream.Url)
				echoResp.Response.Directives = append(echoResp.Response.Directives, directive)
			}
		}
		log.Printf("type AudioPlayer.PlaybackNearlyFinished")
	default:
		log.Printf("type unknown")
	}
}

func infoHandler(echoReq *alexa.EchoRequest, echoResp *alexa.EchoResponse) {
	log.Printf("----> Info Request Typ %s empfangen, UserID %s\n", echoReq.Request.Type, echoReq.Session.User.UserID)
	shared.RegisterDevice(echoReq.Context.System.Device.DeviceId)
}

func radioHandler(echoReq *alexa.EchoRequest, echoResp *alexa.EchoResponse) {
	log.Printf("----> Request für Intent %s empfangen, UserID %s\n", echoReq.Request.Intent.Name, echoReq.Session.User.UserID)
	shared.RegisterDevice(echoReq.Context.System.Device.DeviceId)

	switch echoReq.Request.Intent.Name {
	case "AMAZON.ShuffleOnIntent":
		shared.SwitchShuffle(echoReq.Context.System.Device.DeviceId, true)
		log.Printf("ShuffleOn intent")

		//todo response
		//speech := fmt.Sprint(`<speak>`)
		//card := fmt.Sprint("Shuffle ist jetzt an")
		//speech = fmt.Sprintf("%s%s</speak>", speech, card)
	case "AMAZON.ShuffleOffIntent":
		shared.SwitchShuffle(echoReq.Context.System.Device.DeviceId, false)
		log.Printf("ShuffleOff intent")

		//todo response
		//speech := fmt.Sprint(`<speak>`)
		//card := fmt.Sprint("Shuffle ist jetzt aus")
		//speech = fmt.Sprintf("%s%s</speak>", speech, card)
	case "AMAZON.StartOverIntent":
		//todo implement
		speech := fmt.Sprint(`<speak>`)
		card := fmt.Sprint("Stör mich jetzt nicht, ich hab zu tun!")
		speech = fmt.Sprintf("%s%s</speak>", speech, card)
		log.Printf("StartOver intent")
	case "AMAZON.RepeatIntent":
		//todo implement
		speech := fmt.Sprint(`<speak>`)
		card := fmt.Sprint("Stör mich jetzt nicht, ich hab zu tun!")
		speech = fmt.Sprintf("%s%s</speak>", speech, card)
		log.Printf("Repeat intent")
	case "AMAZON.LoopOnIntent":
		shared.SwitchLoop(echoReq.Context.System.Device.DeviceId, true)
		log.Printf("LoopOff intent")

		//todo response
		//speech := fmt.Sprint(`<speak>`)
		//card := fmt.Sprint("Loop ist jetzt an")
		//speech = fmt.Sprintf("%s%s</speak>", speech, card)
	case "AMAZON.LoopOffIntent":
		shared.SwitchLoop(echoReq.Context.System.Device.DeviceId, false)
		log.Printf("LoopOff intent")

		//todo response
		//speech := fmt.Sprint(`<speak>`)
		//card := fmt.Sprint("Loop ist jetzt aus")
		//speech = fmt.Sprintf("%s%s</speak>", speech, card)
	case "AMAZON.PauseIntent":
		Directive := alexa.EchoDirective{Type: "AudioPlayer.Stop"}
		echoResp.Response.Directives = append(echoResp.Response.Directives, Directive)
		log.Printf("Pause intent")
	case "AMAZON.CancelIntent":
		log.Printf("Cancel intent")
	case "AMAZON.StopIntent":
		Directive := alexa.EchoDirective{Type: "AudioPlayer.Stop"}
		echoResp.Response.Directives = append(echoResp.Response.Directives, Directive)
		log.Printf("Stop intent")
	case "AMAZON.NextIntent":
		if !shared.ShouldStopPlaying(echoReq.Context.System.Device.DeviceId) {
			nextFileName := shared.GetNextFileName(echoReq.Context.System.Device.DeviceId)
			if nextFileName != "" {
				directive := makeAudioPlayDirective(nextFileName)
				log.Println("URL:", directive.AudioItem.Stream.Url)
				echoResp.Response.Directives = append(echoResp.Response.Directives, directive)
			}
		} else {
			//todo inform user that playlist is at end
			log.Printf("todo")
		}
		log.Printf("Next intent")
	case "AMAZON.HelpIntent":
		log.Printf("Help intent")
		fallthrough
	case "CurrentlyPlaying":
		log.Printf("CurrentlyPlaying intent")

		Artist, Album, Track := shared.GetPlayingInfo(echoReq.Context.System.Device.DeviceId)
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
		log.Printf("Resume intent")
		fallthrough
	case "ResumePlay":
		log.Printf("ResumePlay intent")
		nextFileName := shared.GetNextFileName(echoReq.Context.System.Device.DeviceId)
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
			shared.UpdateActualPlaying(echoReq.Context.System.Device.DeviceId, SearchString)
			nextFileName := shared.GetNextFileName(echoReq.Context.System.Device.DeviceId)
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

func makeAudioPlayDirective(fileName string) alexa.EchoDirective {
	return alexa.EchoDirective{
		Type:         "AudioPlayer.Play",
		PlayBehavior: "REPLACE_ALL",
		AudioItem: &alexa.EchoAudioItem{
			Stream: alexa.EchoStream{
				Url:                  shared.UrlEncode(fileName),
				Token:                fmt.Sprintf("NMP-%s", time.Now().Format("20060102T150405999999")),
				OffsetInMilliseconds: 0}}}
}
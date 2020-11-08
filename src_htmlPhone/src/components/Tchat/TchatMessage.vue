<template>
  <div class="phone_app">
    <PhoneTitle :title="channelName" backgroundColor="#090f20" @back="onQuit"/>
    <div class="img-fullscreen" v-if="imgZoom !== undefined" @click.stop="imgZoom = undefined">
      <img :src="imgZoom" />
    </div>
    <div class="phone_content">
      <div class="elements" ref="elementsDiv">
          <div class="element" v-for='(elem, key) in tchatMessages' 
            v-bind:key="elem.id" v-bind:class="{ select: key === selectMessage}"
            >
            <div class="time">{{formatTime(elem.time)}}</div>
            <div class="message" v-bind:class="{ select: key === selectMessage}">
              <img v-if="isSMSImage(elem)" class="sms-img" :src="elem.message">
              <span v-else>{{elem.message}}</span>
            </div>
          </div>
      </div>

      <div class='tchat_write'>
          <input type="text" placeholder="..." v-model="message" @keyup.enter.prevent="sendMessage">
          <span class='tchat_send' @click="sendMessage">></span>
      </div>
    </div>
  </div>
</template>

<script>
import { mapGetters, mapActions } from 'vuex'
import PhoneTitle from './../PhoneTitle'
import Modal from '@/components/Modal/index.js'

export default {
  components: { PhoneTitle },
  data () {
    return {
      message: '',
      channel: '',
      selectMessage: -1,
      imgZoom: undefined,
      ignoreControls: false
    }
  },
  computed: {
    ...mapGetters(['IntlString', 'tchatMessages', 'tchatCurrentChannel', 'useMouse']),
    channelName () {
      return '# ' + this.channel
    }
  },
  watch: {
    tchatMessages () {
      const c = this.$refs.elementsDiv
      c.scrollTop = c.scrollHeight
    }
  },
  methods: {
    setChannel (channel) {
      this.channel = channel
      this.tchatSetChannel({ channel })
    },
    ...mapActions(['tchatSetChannel', 'tchatSendMessage']),
    scrollIntoViewIfNeeded () {
      this.$nextTick(() => {
        const $select = this.$el.querySelector('.select')
        if ($select !== null) {
          $select.scrollIntoViewIfNeeded()
        }
      })
    },
    onUp () {
      if (this.ignoreControls === true) return
      if (this.selectMessage === -1) {
        this.selectMessage = this.tchatMessages.length - 1
      } else {
        this.selectMessage = this.selectMessage === 0 ? 0 : this.selectMessage - 1
      }
      this.scrollIntoViewIfNeeded()
    },
    onDown () {
      if (this.ignoreControls === true) return
      if (this.selectMessage === -1) {
        this.selectMessage = this.tchatMessages.length - 1
      } else {
        this.selectMessage = this.selectMessage === this.tchatMessages.length - 1 ? this.selectMessage : this.selectMessage + 1
      }
      this.scrollIntoViewIfNeeded()
    },
    async onEnter () {
      if (this.ignoreControls === true) return

      if (this.selectMessage !== -1) {
        this.onActionMessage(this.tchatMessages[this.selectMessage])
      } else {
        const rep = await this.$phoneAPI.getReponseText()
        let message = rep.text.trim()
        if (message !== '' && message.length !== 0) {
          this.tchatSendMessage({
            channel: this.channel,
            message
          })
        }
      }
    },
    async onActionMessage (message) {
      try {
        let isGPS = /(-?\d+(\.\d+)?), (-?\d+(\.\d+)?)/.test(message.message)
        let isImage = this.isSMSImage(message)
        if (isGPS) {
          let val = message.message.match(/(-?\d+(\.\d+)?), (-?\d+(\.\d+)?)/)
          this.$phoneAPI.setGPS(val[1], val[3])
          return
        }
        if (isImage) {
          this.imgZoom = message.message
          return
        }
      } catch (e) {
        console.log(e)
      } finally {
        this.ignoreControls = false
        this.selectMessage = -1
      }
    },
    async showOptions () {
      try {
        this.ignoreControls = true
        let choix = [
          {id: 1, title: this.IntlString('APP_MESSAGE_SEND_GPS'), icons: 'fa-location-arrow'},
          {id: 2, title: this.IntlString('APP_MESSAGE_SEND_PHOTO'), icons: 'fa-picture-o'},
          {id: -1, title: this.IntlString('CANCEL'), icons: 'fa-undo'}
        ]
        const data = await Modal.CreateModal({ choix })
        if (data.id === 1) {
          this.tchatSendMessage({
            channel: this.channel,
            message: '%pos%'
          })
        }
        if (data.id === 2) {
          const { url } = await this.$phoneAPI.takePhoto()
          if (url !== null && url !== undefined) {
            this.tchatSendMessage({
              channel: this.channel,
              message: url
            })
          }
        }
        this.ignoreControls = false
      } catch (e) {
        console.log(e)
      } finally {
        this.ignoreControls = false
      }
    },
    sendMessage () {
      const message = this.message.trim()
      if (message.length !== 0) {
        this.tchatSendMessage({
          channel: this.channel,
          message
        })
        this.message = ''
      }
    },
    onBack () {
      if (this.imgZoom !== undefined) {
        this.imgZoom = undefined
        return
      }
      if (this.ignoreControls === true) return
      if (this.useMouse === true && document.activeElement.tagName !== 'BODY') return
      if (this.selectMessage !== -1) {
        this.selectMessage = -1
      } else {
        this.onQuit()
      }
    },
    onQuit () {
      this.$router.push({ name: 'tchat.channel' })
    },
    formatTime (time) {
      const d = new Date(time)
      return d.toLocaleTimeString()
    },
    isSMSImage (mess) {
      return /^https?:\/\/.*\.(png|jpg|jpeg|gif)/.test(mess.message)
    },
    onRight: function () {
      if (this.ignoreControls === true) return
      if (this.selectMessage === -1) {
        this.showOptions()
      }
    }
  },
  created () {
    if (!this.useMouse) {
      this.$bus.$on('keyUpArrowDown', this.onDown)
      this.$bus.$on('keyUpArrowUp', this.onUp)
      this.$bus.$on('keyUpEnter', this.onEnter)
      this.$bus.$on('keyUpArrowRight', this.onRight)
    } else {
      this.selectMessage = -1
    }
    this.$bus.$on('keyUpBackspace', this.onBack)
    this.setChannel(this.$route.params.channel)
  },
  mounted () {
    window.c = this.$refs.elementsDiv
    const c = this.$refs.elementsDiv
    c.scrollTop = c.scrollHeight
  },
  beforeDestroy () {
    this.$bus.$off('keyUpArrowDown', this.onDown)
    this.$bus.$off('keyUpArrowUp', this.onUp)
    this.$bus.$off('keyUpEnter', this.onEnter)
    this.$bus.$off('keyUpArrowRight', this.onRight)
    this.$bus.$off('keyUpBackspace', this.onBack)
  }
}
</script>

<style scoped>

.elements{
  height: calc(100% - 56px);
  background-color: #20201d;
  color: white;
  display: flex;
  flex-direction: column;
  padding-bottom: 12px;
  overflow-y: auto;
}

.element{
  color: #a6a28c;
  flex: 0 0 auto;
  width: 100%;
  display: flex;
  max-width: 100%;
  /* margin: 9px 12px;
  line-height: 18px;
  font-size: 18px;
  padding-bottom: 6px;
  
  flex-direction: row;
  height: 60px; */
}

.img-fullscreen {
  position: fixed;
  z-index: 999999;
  background-color: rgba(20, 20, 20, 0.8);
  left: 0;
  top: 0;
  right: 0;
  bottom: 0;
  display: flex;
  justify-content: center;
  align-items: center;
}
.img-fullscreen img {
  display: flex;
  max-width: 90vw;
  max-height: 95vh;
}

.sms-img{
  width: 100%;
  height: auto;
}

.element.select, .element:hover {
  background-color: rgb(0, 0, 0) !important;
}

.time{
  padding-right: 6px;
  font-size: 12px;

}

.message{
  width: 100%;
  color: #FFC629;
}

.tchat_write{
    height: 56px;
    widows: 100%;
    background: #20201d;
    display: flex;
    justify-content: space-around;
    align-items: center;
}
.tchat_write input{
    width: 75%;
    margin-left: 6%;
    border: none;
    outline: none;
    font-size: 16px;
    padding: 3px 5px;
    float: left;
    height: 36px;
    background-color: #00071c;
    color: white;
}
.tchat_write input::placeholder {
  color: #ccc;
}
.tchat_send{
    width: 32px;
    height: 32px;
    float: right;
    border-radius: 50%;
    background-color: #5e0576;
    margin-right: 12px;
    margin-bottom: 2px;
    color: white;
    line-height: 32px;
    text-align: center;
}
.elements::-webkit-scrollbar-track
  {
      box-shadow: inset 0 0 6px rgba(0,0,0,0.3);
      background-color: #a6a28c;
  }
.elements::-webkit-scrollbar
  {
      width: 3px;
      background-color: transparent;
  }
.elements::-webkit-scrollbar-thumb
  {
      background-color: #FFC629;
  }
</style>

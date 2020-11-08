<template>
  <div class="contact">
    <list :list='lcontacts' :disable="disableList" :title="IntlString('APP_CONTACT_TITLE')" @back="back" @select='onSelect' @option='onOption'></list>
  </div>
</template>

<script>
import { mapGetters, mapActions } from 'vuex'
import { generateColorForStr } from '@/Utils'
import List from './../List.vue'
import Modal from '@/components/Modal/index.js'

export default {
  components: {
    List
  },
  data () {
    return {
      disableList: false
    }
  },
  computed: {
    ...mapGetters(['IntlString', 'contacts', 'useMouse']),
    lcontacts () {
      let addContact = {display: this.IntlString('APP_CONTACT_NEW'), letter: '+', num: '', id: -1}
      return [addContact, ...this.contacts.map(e => {
        e.backgroundColor = e.backgroundColor || generateColorForStr(e.number)
        return e
      })]
    }
  },
  methods: {
    ...mapActions(['blockContact']),
    onSelect (contact) {
      if (contact.id === -1) {
        this.$router.push({ name: 'contacts.view', params: { id: contact.id } })
      } else {
        this.$router.push({ name: 'messages.view', params: { number: contact.number, display: contact.display } })
      }
    },
    onOption (contact) {
      if (contact.id === -1 || contact.id === undefined) return
      this.disableList = true
      Modal.CreateModal({
        choix: [
          {id: 1, title: this.IntlString('APP_CONTACT_EDIT'), icons: 'fa-circle-o', color: 'orange'},
          {id: 2, title: this.IntlString('APP_CONTACT_BLOCK'), icons: 'fa-ban', color: 'red'},
          {id: 3, title: 'Annuleren', icons: 'fa-undo'}
        ]
      }).then(rep => {
        if (rep.id === 1) {
          this.$router.push({path: 'contact/' + contact.id})
        } else if (rep.id === 2) {
          this.$phoneAPI.blockContact(contact.id, contact.blocked)
        }
        this.disableList = false
      })
    },
    back () {
      if (this.disableList === true) return
      this.$router.push({ name: 'home' })
    }
  },
  created () {
    if (!this.useMouse) {
      this.$bus.$on('keyUpBackspace', this.back)
    }
  },

  beforeDestroy () {
    this.$bus.$off('keyUpBackspace', this.back)
  }
}
</script>

<style scoped>
.contact{
  position: relative;
  left: 0;
  top: 0;
  width: 100%;
  height: 100%;
}
</style>

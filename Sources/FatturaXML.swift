import Foundation

// Lettura di una fattura elettronica FatturaPA (XML SDI), tutta sul telefono.
// Prende solo ciò che serve al calcolo: numero, data, cliente, importo.

final class LettoreFatturaPA: NSObject, XMLParserDelegate {
    struct Esito {
        var fatture: [Fattura] = []
        var errori: [String] = []
    }

    private var percorso: [String] = []
    private var testo = ""
    private var cliente = ""
    private var nome = ""
    private var cognome = ""
    /// Partita IVA di chi ha emesso la fattura (CedentePrestatore)
    private var emittente = ""
    /// La partita IVA del profilo: se la fattura l'ha emessa un altro, è un acquisto e non un incasso
    private var miaPartitaIVA = ""
    private struct Corpo {
        var numero: String?
        var data: String?
        /// TD01 fattura, TD04 nota di credito…
        var tipo: String?
        var totale: Double?
        var bollo: Double?
        /// EUR, USD…: solo le fatture in euro entrano da sole
        var divisa: String?
        var imponibili = 0.0
        var trovatoImponibile = false
    }
    private var corpo: Corpo?
    private var esito = Esito()

    static func leggi(_ dati: Data, partitaIVA: String? = nil) -> Esito {
        let lettore = LettoreFatturaPA()
        lettore.miaPartitaIVA = (partitaIVA ?? "").filter(\.isNumber)
        let parser = XMLParser(data: dati)
        parser.shouldProcessNamespaces = true
        parser.delegate = lettore
        let letto = parser.parse()
        if !letto && lettore.esito.fatture.isEmpty {
            return Esito(errori: ["Il file non sembra una fattura elettronica XML.".tradotto])
        }
        if !letto {
            // File rovinato a metà: le fatture lette entrano, ma l'utente deve sapere che potrebbero mancarne
            lettore.esito.errori.append("Il file è rovinato: alcune fatture potrebbero mancare. Controlla l'elenco.".tradotto)
        }
        if lettore.esito.fatture.isEmpty && lettore.esito.errori.isEmpty {
            lettore.esito.errori.append("Il file non sembra una fattura elettronica XML.".tradotto)
        }
        return lettore.esito
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String] = [:]) {
        percorso.append(elementName)
        testo = ""
        if elementName == "FatturaElettronicaBody" {
            corpo = Corpo()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        testo += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let valore = testo.trimmingCharacters(in: .whitespacesAndNewlines)
        let nelCliente = percorso.contains("CessionarioCommittente")
        if percorso.contains("CedentePrestatore") && percorso.contains("IdFiscaleIVA") && elementName == "IdCodice" {
            emittente = valore.filter(\.isNumber)
        }
        let neiDatiDocumento = percorso.contains("DatiGeneraliDocumento")

        if nelCliente {
            switch elementName {
            case "Denominazione": cliente = valore
            case "Nome": nome = valore
            case "Cognome": cognome = valore
            default: break
            }
        }
        if corpo != nil {
            switch elementName {
            case "TipoDocumento" where neiDatiDocumento: corpo?.tipo = valore
            case "Divisa" where neiDatiDocumento: corpo?.divisa = valore.uppercased()
            case "Numero" where neiDatiDocumento && corpo?.numero == nil: corpo?.numero = valore
            case "Data" where neiDatiDocumento && corpo?.data == nil: corpo?.data = valore
            case "ImportoTotaleDocumento": corpo?.totale = Double(valore)
            case "ImportoBollo": corpo?.bollo = Double(valore)
            case "ImponibileImporto":
                corpo?.imponibili += Double(valore) ?? 0
                corpo?.trovatoImponibile = true
            case "FatturaElettronicaBody":
                chiudiCorpo()
            default: break
            }
        }
        percorso.removeLast()
        testo = ""
    }

    private func chiudiCorpo() {
        guard let c = corpo else { return }
        corpo = nil
        var importo: Double?
        if let totale = c.totale {
            // Il bollo addebitato al cliente non è un ricavo dell'attività
            importo = totale - (c.bollo ?? 0)
        } else if c.trovatoImponibile {
            importo = c.imponibili
        }
        // Una fattura emessa da un'altra partita IVA è una spesa (per esempio arrivata con «Apri con»): non è un incasso
        if !miaPartitaIVA.isEmpty && !emittente.isEmpty && emittente != miaPartitaIVA {
            esito.errori.append(String(localized: "Fattura \(c.numero ?? ""): l'ha emessa un'altra partita IVA, quindi è una spesa e non un incasso. Non aggiunta."))
            return
        }
        // Una fattura in un'altra valuta non si somma agli euro: l'importo in euro lo sa solo chi l'ha incassata
        if let divisa = c.divisa, !divisa.isEmpty, divisa != "EUR" {
            esito.errori.append(String(localized: "Fattura \(c.numero ?? ""): è in \(divisa). Aggiungila a mano con l'importo in euro che hai ricevuto."))
            return
        }
        // Una nota di credito toglie soldi invece di aggiungerli: non diventa un incasso
        if c.tipo == "TD04" {
            esito.errori.append(String(localized: "Nota di credito \(c.numero ?? ""): non aggiunta. Se riduce un incasso già segnato, correggilo a mano."))
            return
        }
        guard let numero = c.numero, let data = c.data, let importo else {
            esito.errori.append(String(localized: "Fattura \(c.numero ?? "senza numero".tradotto): dati mancanti, aggiungila a mano."))

            return
        }
        let chi = !cliente.isEmpty ? cliente : [nome, cognome].filter { !$0.isEmpty }.joined(separator: " ")
        esito.fatture.append(Fattura(numero: numero, data: Giorno.da(data), cliente: chi.isEmpty ? "Cliente".tradotto : chi,
                                     importo: arrotonda(importo), incassata: false, origine: .xml))
    }
}

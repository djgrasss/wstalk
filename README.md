"W-Stalk"
=========

Location Awareness -projektityö, kevät 2012
Oona Räisänen (013337731)
oona.raisanen@helsinki.fi

YLEISTÄ
-------

Projektini on WLAN-paikannusohjelma Kumpulan kampukselle.
Se keskittyy Exactumiin ja muihin tiloihin, joita tietojen-
käsittelytieteen opiskelijat saattavat käyttää. Alusta on
Linux, ohjelmointikieli Perl ja tietoa tallennetaan myös
SQLite-tiedostoon.

Varsinaisen ohjelman lisäksi tein projektiin myös hieman
karttataidetta Inkscapella.

Avaintermejä projektin käyttämän metodin takana:
hyperbolic location fingerprinting (HLF), Bayesian inference


KÄYTTÖ
------

HLF-metodi vaatii keräyskuuntelun. Se tehdään viemällä
laite kuunneltavaan huoneeseen ja ajamalla justrecord.pl.
Skripti kysyy huoneelle asetettavan nimen ja kuuntelee
WLAN-piiriä while-silmukassa, kunnes käyttäjä painaa enteriä.
Yleensä yli 20 otosta huonetta kohden on riittävä.

Kuuntelun jälkeen raakadatasta on tehtävä radiokartta
ratio.pl-skriptillä. Standardisyötteenä annetaan
raw_recorded.csv tai siitä grepillä erotetut, halutut
rivit. ratio.pl laskee tukiasemien voimakkuuksien suhteet,
määrittää oletetun normaalijakauman parametrit ja
tallentaa ne tietokannaksi ratio.sqlite-tiedostoon.

Itse paikannus tapahtuu whereami.pl-skriptillä. Skripti
tulostaa päätteeseen todennäköisyyksiä eri sijainneista ja
kaikken todennäköisimmän sijainnin erikseen. Se myös piirtää
sijainnin vilkkuvana ympyränä kartalle (where.gif)
ImageMagickin avulla.

justrecord- ja whereami-skriptien on saatava käyttää
iwlist-ohjelmaa root-oikeuksilla. Tämän helpottamiseksi
on sudoersiin lisättävä (visudo-komennolla) esimerkiksi
seuraava rivi:

%admin ALL=NOPASSWD: /sbin/iwlist


TARKKUUS
--------

Ohjelma pystyy parhaimmillaan alle huoneen tarkkuuteen.
Usein se pystyy erottamaan esimerkiksi, ollaanko Gurulan
sohvan vai pöydän ääressä. Tarkkuus kärsii kuitenkin
huomattavasti ajan kulumisesta - jo muutamassa viikossa
paikannukset alkavat osua enimmäkseen viereisiin
huoneisiin.


ONGELMIA
--------

Projektin hankalin osuus oli käytännössä päästä kaikkiin
toivomiini paikkoihin keräämään dataa. Kuuntelu oli tehtävä
luentojen tauoilla tai ovien ollessa onnekkaasti avoinna.

Osoittautui, että paikannus toimii todella epäluotettavasti
tietyissä suurissa ja avoimissa tiloissa, kuten A111-salin
edessä. Minun oli poistettava kaikki sillä paikalla tehdyt
mittaukset, sillä muuten ohjelma paikansi minut hyvin usein
sinne vaikka olin aivan eri puolella taloa ja eri
kerroksessa. En ole aivan varma, mistä tämä johtuu. Myös
edellä mainitsemani radiokartan "rapistuminen" koitui
ongelmaksi.



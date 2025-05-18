# PROYEK AKHIR SISTEM EMBEDDED - KELOMPOK 1
```
Adi Nugroho - 2306208546
Azka Nabihan Hilmy - 2306250541
Benedict Aurelius - 2306209095
Nugroho Ulil Abshar - 2306229310
```
## Introduction to the problem and the solution
Dalam kehidupan sehari-hari, suhu ruangan yang meningkat dapat menyebabkan 
ketidaknyamanan bagi kita semua, khususnya kalau kita tinggal di negara tropis seperti 
Indonesia. Kipas angin sendiri merupakan salah satu teknologi yang kita gunakan 
sehari-hari untuk menjadi solusi dari permasalahan tersebut. Biasanya kipas angin 
digunakan untuk mengurangi rasa panas yang kita rasakan. Namun, sebagian besar kipas 
angin masih dioperasikan secara manual, sehingga rasanya kurang efisien dalam 
merespons perubahan suhu secara real-time.

Maka dari itu, kami dari kelompok 1, merancang serta mengusulkan pembuatan 
sistem embedded kipas angin otomatis yang dapat menyesuaikan kecepatan putaran 
berdasarkan suhu ruangan. Dengan sistem ini, kecepatan kipas akan meningkat seiring meningkatnya suhu 
ruangan dan akan menurun ketika suhu menurun, sehingga menciptakan kenyamanan 
secara otomatis tanpa intervensi manual. Sistem ini menggunakan sensor DHT11 untuk membaca suhu 
secara real-time, dan mengatur kecepatan kipas melalui pengendalian sinyal PWM dari 
arduino. 

## Hardware design and implementation details
### Component

| Component     | Jumlah |
|---------------|--------|
| Arduino Uno   | 1 buah |
| Breadboard    | 1 buah |
| LCD 16x2      | 1 buah |
| DHT11 Sensor  | 1 buah |
| DC Motor      | 1 buah |
| L298N Driver  | 1 buah |
| Baterai 1.5V  | 4 buah |
| Jumper        | -      |

### Hardware Design and Output 
- MODE LOW:
![FOTO1](https://imgur.com/MtjhUT2.png)

- MODE MEDIUM
![FOTO2](https://imgur.com/VAQMqEW.png)

- MODE HIGH
![FOTO3](https://imgur.com/kw66c3s.png)

- FLOWCHART

![FOTO4](https://imgur.com/BxqT6l8.png)

EXPLANATION:
Untuk dapat mengontrol kecepatan motor, akan digunakan driver motor bertipe 
L298N sehingga kecepatan dari motor dapat diatur secara dinamis dengan 
memanfaatkan PWM yang ada pada timer1. L298N juga diperlukan sebagai 
media untuk baterai yang akan digunakan untuk memberikan daya ke motor 
dikarenakan tipe motor DC yang digunakan (RS 130) membutuhkan hingga 6V 
untuk dapat berjalan dengan baik, sedangkan power dari arduino adalah 5V 
dengan arus pada pin-nya jauh lebih kecil dari yang dibutuhkan motor. 
Pada LCD, akan digunakan juga sebuah potentiometer yang berfungsi mengatur 
kecerahan serta kontras dari LCD sehingga tampilan LCD dapat diperjelas. 
Potentiometer akan dihubungkan dengan pin VEE pada LCD. LCD akan 
dihubungkan ke arduino melalui pin D4 - D7 pada LCD, yang akan terhubung ke 
pin PD4 - PD7 pada arduino uno.

## Software implementation details
- Pada Project ini, terdapat implementasi dari timer untuk menghasilkan delay yang 
akurat guna menunjang kerja dari sensor, LCD, dan kecepatan motor. Delay yang digunakan sebesar 50 mikrosekon. Walaupun tidak semua delay menggunakan timer.

- Terdapat rangkaian LCD LCD untuk menampilkan 
informasi suhu yang terbaca pada sensor serta mode kecepatan dari motor DC (SLOW, MEDIUM dan HIGH), tergantung putaran dari motor DC

- Sensor yang digunakan adalah sensor DT11. Sensor DHT11 merupakan sensor suhu dan 
kelembaban berbasis digital. Ketika DT11 dinyalakan akan ada delay selama 2 detik sebelum melakukan inisiasi. Jika suhu yang terbaca 
berada di bawah 20 derajat celcius, maka motor akan berputar dengan kecepatan 
minim atau berada dalam mode LOW, jika suhu berada di antara 20 derajat hingga 29 derajat celcius, maka 
kecepatan motor dinaikkan ke kecepatan sedang (50% dari kecepatan maksimum) atau MEDIUM
dan jika suhu berada pada 30 derajat celcius atau lebih, motor akan diputar 
dengan kecepatan maksimum atau HIGH.

## Test results and performance evaluation
- Simulasi dengan Proteus
Dalam simulasi ini, seluruh rangkaian virtual disusun mengikuti 
desain hardware yang telah dirancang di bab sebelumnya, termasuk koneksi 
antara Arduino Uno, DHT11, L298N, DC motor, dan LCD 16x2. Hasilnya terdapat indikasi bahwa rangkaian tersebut berhasil 
memenuhi semua parameter kriteria yang ada. Dimana rangkaian tersebut berhasil 
membaca suhu input melalui Sensor DHT11, mengatur kecepatan kipas secara dinamis 
seiring dengan berubahnya suhu yang dibaca, dan menampilkan hasil bacaan suhu dan 
kecepatan kipas ke LCD. Hasilnya sendiri, kecepatan kipas memiliki tiga mode, yaitu 
mode LOW, mode MEDIUM, dan mode HIGH dengan spesfikasi yang sesuai dengan apa yang ada pada software implementation details.

- Simulasi Fisik
Rangkaian ini belum sepenuhnya jadi dan belum dapat dilakukan 
pengujian dikarenakan motor driver L298N kami belum sampai. Kami akan 
merangkainya segera setelah drivernya sampai dan akan memastikan rangkaian 
fisik berjalan dengan baik saat jadwal presentasi. 

## Conclusion and future work
Berdasarkan hasil test dan evaluasi yang telah dilakukan menggunakan program simulasi 
Proteus, dapat disimpulkan bahwa fungsi dari rangkaian Fan yang dibuat tidak memiliki kendala 
yang signifikan. Fan dapat berpindah ke mode kecepatan yang berbeda tergantung dari suhu 
ruangan yang terbaca pada sensor, dan LCD dapat dengan akurat menampilkan informasi suhu 
yang terbaca pada sensor dan mode kecepatan Fan. Sistem pembacaan sensor DHT11 oleh 
arduino juga berjalan dengan baik berkat implementasi delay yang akurat. Secara umum, fungsi 
rangkaian pada project ini dapat berjalan dengan baik.
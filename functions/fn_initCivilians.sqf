/*
 * LL_fnc_initCivilians
 *
 * Description:
 *   (Serveur uniquement) Initialise les bases de données de noms perses/afghans,
 *   les pools visuels (visages, couvre-chefs, barbes, chargements bandits) et
 *   collecte les unités template_XX placées dans l'éditeur. Enregistre leur
 *   apparence dans MISSION_CivilianTemplates, puis les supprime de la carte.
 *   Supprime également les unités Max_Tak (femmes mod) et CUP civilians résiduels.
 *   Applique enfin LL_fnc_applyCivilianTemplate aux unités déjà présentes et
 *   installe le gestionnaire EntityCreated pour les spawns futurs.
 *
 * Convention de genre (INFO.md) :
 *   template_01 à template_16 → femmes (classe contient "woman")
 *   template_17 et au-delà   → hommes
 *   La détection se fait par le nom de classe (plus robuste que le numéro).
 *
 * Arguments:
 *   Aucun
 *
 * Return Value:
 *   <BOOL> true si exécuté, false si non-serveur
 *
 * Locality:
 *   Server uniquement
 *
 * Public:
 *   Non
 *
 * Example:
 *   [] call LL_fnc_initCivilians;
 */

#include "..\macros.hpp"

if (!isServer) exitWith { false };

// ============================================================
// === BASES DE DONNÉES DE NOMS (Perse / Afghan / Takistanais)
// ============================================================

MISSION_CivilianNames_Male = [
    ["Afaq Khan",             "Afaq",       "Khan"],
    ["Akhtar Durrani",        "Akhtar",     "Durrani"],
    ["Anis Kakar",            "Anis",       "Kakar"],
    ["Azad Mousavi",          "Azad",       "Mousavi"],
    ["Faisal Karimi",         "Faisal",     "Karimi"],
    ["Habib Noori",           "Habib",      "Noori"],
    ["Jalil Hashemi",         "Jalil",      "Hashemi"],
    ["Karim Jafari",          "Karim",      "Jafari"],
    ["Omar Faizi",            "Omar",       "Faizi"],
    ["Rashid Taheri",         "Rashid",     "Taheri"],
    ["Abbas Alizadeh",        "Abbas",      "Alizadeh"],
    ["Abdullah Wardak",       "Abdullah",   "Wardak"],
    ["Adel Termos",           "Adel",       "Termos"],
    ["Adnan Malik",           "Adnan",      "Malik"],
    ["Ahmad Shah",            "Ahmad",      "Shah"],
    ["Ali Rezaei",            "Ali",        "Rezaei"],
    ["Amin Maalouf",          "Amin",       "Maalouf"],
    ["Amir Hosseini",         "Amir",       "Hosseini"],
    ["Amjad Sabri",           "Amjad",      "Sabri"],
    ["Arash Kamali",          "Arash",      "Kamali"],
    ["Arsalan Kazemi",        "Arsalan",    "Kazemi"],
    ["Asadullah Khalid",      "Asadullah",  "Khalid"],
    ["Ashraf Baradar",        "Ashraf",     "Baradar"],
    ["Atiq Rahimi",           "Atiq",       "Rahimi"],
    ["Ayman Odeh",            "Ayman",      "Odeh"],
    ["Aziz Ansari",           "Aziz",       "Ansari"],
    ["Babur Dostum",          "Babur",      "Dostum"],
    ["Bahram Radan",          "Bahram",     "Radan"],
    ["Baktash Siawash",       "Baktash",    "Siawash"],
    ["Bashir Ahmad",          "Bashir",     "Ahmad"],
    ["Bassam Tibi",           "Bassam",     "Tibi"],
    ["Behrouz Vosooghi",      "Behrouz",    "Vosooghi"],
    ["Bilal Mansour",         "Bilal",      "Mansour"],
    ["Boulos Khoury",         "Boulos",     "Khoury"],
    ["Cyrus Zarei",           "Cyrus",      "Zarei"],
    ["Danish Karokhel",       "Danish",     "Karokhel"],
    ["Dariush Eghbali",       "Dariush",    "Eghbali"],
    ["Dawood Sarkhosh",       "Dawood",     "Sarkhosh"],
    ["Ehsan Aman",            "Ehsan",      "Aman"],
    ["Elias Yasin",           "Elias",      "Yasin"],
    ["Emal Zakarya",          "Emal",       "Zakarya"],
    ["Esmail Khoi",           "Esmail",     "Khoi"],
    ["Fahim Dashty",          "Fahim",      "Dashty"],
    ["Farhad Darya",          "Farhad",     "Darya"],
    ["Farid Zaland",          "Farid",      "Zaland"],
    ["Farzad Farzin",         "Farzad",     "Farzin"],
    ["Fawad Ramiz",           "Fawad",      "Ramiz"],
    ["Faysal Qureshi",        "Faysal",     "Qureshi"],
    ["Fouad Ajami",           "Fouad",      "Ajami"],
    ["Ghafoor Bakhsh",        "Ghafoor",    "Bakhsh"],
    ["Ghassan Kanafani",      "Ghassan",    "Kanafani"],
    ["Ghulam Haider",         "Ghulam",     "Haider"],
    ["Gulbuddin Hekmatyar",   "Gulbuddin",  "Hekmatyar"],
    ["Hafez Assad",           "Hafez",      "Assad"],
    ["Hamid Karzai",          "Hamid",      "Karzai"],
    ["Hamza Yusuf",           "Hamza",      "Yusuf"],
    ["Haroon Yusufi",         "Haroon",     "Yusufi"],
    ["Hassan Rouhani",        "Hassan",     "Rouhani"],
    ["Hekmat Khalil",         "Hekmat",     "Khalil"],
    ["Hesam Din",             "Hesam",      "Din"],
    ["Homayoun Shajarian",    "Homayoun",   "Shajarian"],
    ["Hossein Alizadeh",      "Hossein",    "Alizadeh"],
    ["Ibrahim Maalouf",       "Ibrahim",    "Maalouf"],
    ["Idris Sadiqi",          "Idris",      "Sadiqi"],
    ["Ilyas Kashmiri",        "Ilyas",      "Kashmiri"],
    ["Imran Khan",            "Imran",      "Khan"],
    ["Ismael Jalal",          "Ismael",     "Jalal"],
    ["Jabbar Patel",          "Jabbar",     "Patel"],
    ["Jafar Panahi",          "Jafar",      "Panahi"],
    ["Jalal Talabani",        "Jalal",      "Talabani"],
    ["Jamal Khashoggi",       "Jamal",      "Khashoggi"],
    ["Jamil Sadeqi",          "Jamil",      "Sadeqi"],
    ["Javed Akhtar",          "Javed",      "Akhtar"],
    ["Jawad Sharif",          "Jawad",      "Sharif"],
    ["Kabir Bedi",            "Kabir",      "Bedi"],
    ["Kamal Salibi",          "Kamal",      "Salibi"],
    ["Kamran Hooman",         "Kamran",     "Hooman"],
    ["Kasra Nouri",           "Kasra",      "Nouri"],
    ["Kaveh Ahangar",         "Kaveh",      "Ahangar"],
    ["Khalid Hosseini",       "Khalid",     "Hosseini"],
    ["Khalil Zad",            "Khalil",     "Zad"],
    ["Khosrow Shakibai",      "Khosrow",    "Shakibai"],
    ["Kianoush Ayari",        "Kianoush",   "Ayari"],
    ["Latif Pedram",          "Latif",      "Pedram"],
    ["Mahdi Darius",          "Mahdi",      "Darius"],
    ["Mahmood Khan",          "Mahmood",    "Khan"],
    ["Majid Majidi",          "Majid",      "Majidi"],
    ["Malek Jahan",           "Malek",      "Jahan"],
    ["Mansour Bahrami",       "Mansour",    "Bahrami"],
    ["Marwan Barghouti",      "Marwan",     "Barghouti"],
    ["Masoud Shojaei",        "Masoud",     "Shojaei"],
    ["Mehdi Mahdavikia",      "Mehdi",      "Mahdavikia"],
    ["Mirwais Nejat",         "Mirwais",    "Nejat"],
    ["Mohammad Reza",         "Mohammad",   "Reza"],
    ["Mohsen Makhmalbaf",     "Mohsen",     "Makhmalbaf"],
    ["Morteza Pashaei",       "Morteza",    "Pashaei"],
    ["Munir Bashir",          "Munir",      "Bashir"],
    ["Mustafa Sandal",        "Mustafa",    "Sandal"],
    ["Nabil Shoail",          "Nabil",      "Shoail"],
    ["Nader Shah",            "Nader",      "Shah"],
    ["Naguib Mahfouz",        "Naguib",     "Mahfouz"],
    ["Najibullah Ahmadzai",   "Najibullah", "Ahmadzai"],
    ["Naseeruddin Shah",      "Naseeruddin","Shah"],
    ["Nasser Al-Attiyah",     "Nasser",     "Al-Attiyah"],
    ["Navid Negahban",        "Navid",      "Negahban"],
    ["Nizar Qabbani",         "Nizar",      "Qabbani"],
    ["Omid Djalili",          "Omid",       "Djalili"],
    ["Osman Mir",             "Osman",      "Mir"],
    ["Parviz Parastui",       "Parviz",     "Parastui"],
    ["Payam Dehkordi",        "Payam",      "Dehkordi"],
    ["Qais Ulfat",            "Qais",       "Ulfat"],
    ["Qasim Soleimani",       "Qasim",      "Soleimani"],
    ["Rafik Hariri",          "Rafik",      "Hariri"],
    ["Rahim Shah",            "Rahim",      "Shah"],
    ["Rahman Baba",           "Rahman",     "Baba"],
    ["Rami Malek",            "Rami",       "Malek"],
    ["Ramzi Yousef",          "Ramzi",      "Yousef"],
    ["Reza Attaran",          "Reza",       "Attaran"],
    ["Rostam Farrokhzad",     "Rostam",     "Farrokhzad"],
    ["Saami Yusuf",           "Saami",      "Yusuf"],
    ["Saeed Rad",             "Saeed",      "Rad"],
    ["Salahuddin Rabbani",    "Salahuddin", "Rabbani"],
    ["Salim Shaheen",         "Salim",      "Shaheen"],
    ["Salman Khan",           "Salman",     "Khan"],
    ["Saman Jalili",          "Saman",      "Jalili"],
    ["Sardar Azmoun",         "Sardar",     "Azmoun"],
    ["Shahrukh Khan",         "Shahrukh",   "Khan"],
    ["Shahzad Ismaily",       "Shahzad",    "Ismaily"],
    ["Shams Langroudi",       "Shams",      "Langroudi"],
    ["Sohrab Sepehri",        "Sohrab",     "Sepehri"],
    ["Sulaiman Layeq",        "Sulaiman",   "Layeq"],
    ["Tahir Qadri",           "Tahir",      "Qadri"],
    ["Tarek Fatah",           "Tarek",      "Fatah"],
    ["Tariq Ramadan",         "Tariq",      "Ramadan"],
    ["Ubaidullah Jan",        "Ubaidullah", "Jan"],
    ["Vahid Amiri",           "Vahid",      "Amiri"],
    ["Walid Al-Shehri",       "Walid",      "Al-Shehri"],
    ["Waseem Badami",         "Waseem",     "Badami"],
    ["Yasin Malik",           "Yasin",      "Malik"],
    ["Yasser Arafat",         "Yasser",     "Arafat"],
    ["Yousef Chahine",        "Yousef",     "Chahine"],
    ["Zalmay Khalilzad",      "Zalmay",     "Khalilzad"],
    ["Zarif Zarif",           "Zarif",      "Zarif"],
    ["Zayn Malik",            "Zayn",       "Malik"],
    ["Zia Massoud",           "Zia",        "Massoud"]
];

MISSION_CivilianNames_Female = [
    ["Aadila Nouri",          "Aadila",     "Nouri"],
    ["Aaliyah Massoud",       "Aaliyah",    "Massoud"],
    ["Amani Rahimi",          "Amani",      "Rahimi"],
    ["Anisa Wahab",           "Anisa",      "Wahab"],
    ["Bahar Pars",            "Bahar",      "Pars"],
    ["Fatima Bhutto",         "Fatima",     "Bhutto"],
    ["Ghazal Sadat",          "Ghazal",     "Sadat"],
    ["Jamila Afghani",        "Jamila",     "Afghani"],
    ["Kubra Khademi",         "Kubra",      "Khademi"],
    ["Latifa Nabizada",       "Latifa",     "Nabizada"],
    ["Malalai Joya",          "Malalai",    "Joya"],
    ["Sima Samar",            "Sima",       "Samar"],
    ["Abir Al-Sahlani",       "Abir",       "Al-Sahlani"],
    ["Afra Jalil",            "Afra",       "Jalil"],
    ["Aisha Wardak",          "Aisha",      "Wardak"],
    ["Aleena Khan",           "Aleena",     "Khan"],
    ["Alia Zadeh",            "Alia",       "Zadeh"],
    ["Almas Durrani",         "Almas",      "Durrani"],
    ["Amal Alamuddin",        "Amal",       "Alamuddin"],
    ["Amira Casar",           "Amira",      "Casar"],
    ["Anahita Ratebzad",      "Anahita",    "Ratebzad"],
    ["Anbar Nadiya",          "Anbar",      "Nadiya"],
    ["Aqsa Parvez",           "Aqsa",       "Parvez"],
    ["Ara Qadir",             "Ara",        "Qadir"],
    ["Areeba Habib",          "Areeba",     "Habib"],
    ["Arezoo Tanha",          "Arezoo",     "Tanha"],
    ["Arwa Damon",            "Arwa",       "Damon"],
    ["Asal Badiee",           "Asal",       "Badiee"],
    ["Asma Jahangir",         "Asma",       "Jahangir"],
    ["Asra Nomani",           "Asra",       "Nomani"],
    ["Atefeh Razavi",         "Atefeh",     "Razavi"],
    ["Azadeh Moaveni",        "Azadeh",     "Moaveni"],
    ["Aziza Siddiqui",        "Aziza",      "Siddiqui"],
    ["Azra Akrami",           "Azra",       "Akrami"],
    ["Badra Ali",             "Badra",      "Ali"],
    ["Bahira Sherif",         "Bahira",     "Sherif"],
    ["Balqis Ahmed",          "Balqis",     "Ahmed"],
    ["Banu Ghazanfar",        "Banu",       "Ghazanfar"],
    ["Baran Kosari",          "Baran",      "Kosari"],
    ["Baria Alamuddin",       "Baria",      "Alamuddin"],
    ["Basma Hassan",          "Basma",      "Hassan"],
    ["Batool Fakoor",         "Batool",     "Fakoor"],
    ["Bayan Mahmoud",         "Bayan",      "Mahmoud"],
    ["Beheshta Arghand",      "Beheshta",   "Arghand"],
    ["Behnaz Jafari",         "Behnaz",     "Jafari"],
    ["Benafsha Yaqoobi",      "Benafsha",   "Yaqoobi"],
    ["Bushra Maneka",         "Bushra",     "Maneka"],
    ["Dalia Mogahed",         "Dalia",      "Mogahed"],
    ["Dana Ghazi",            "Dana",       "Ghazi"],
    ["Dania Khatib",          "Dania",      "Khatib"],
    ["Darya Safai",           "Darya",      "Safai"],
    ["Deena Aljuhani",        "Deena",      "Aljuhani"],
    ["Delaram Karkhir",       "Delaram",    "Karkhir"],
    ["Delbar Nazari",         "Delbar",     "Nazari"],
    ["Dorsa Derakhshani",     "Dorsa",      "Derakhshani"],
    ["Dua Khalil",            "Dua",        "Khalil"],
    ["Durkhanai Ayubi",       "Durkhanai",  "Ayubi"],
    ["Elaha Soroor",          "Elaha",      "Soroor"],
    ["Elham Shahin",          "Elham",      "Shahin"],
    ["Elnaz Shakerdoost",     "Elnaz",      "Shakerdoost"],
    ["Esra Bilgic",           "Esra",       "Bilgic"],
    ["Faiza Darkhani",        "Faiza",      "Darkhani"],
    ["Fakhria Khalil",        "Fakhria",    "Khalil"],
    ["Farah Pahlavi",         "Farah",      "Pahlavi"],
    ["Farangis Yeganegi",     "Farangis",   "Yeganegi"],
    ["Farhana Qasimi",        "Farhana",    "Qasimi"],
    ["Fariba Hachtroudi",     "Fariba",     "Hachtroudi"],
    ["Farkhunda Zahra",       "Farkhunda",  "Zahra"],
    ["Farzaneh Kaboli",       "Farzaneh",   "Kaboli"],
    ["Fatemeh Motamed",       "Fatemeh",    "Motamed"],
    ["Fawzia Koofi",          "Fawzia",     "Koofi"],
    ["Fereshteh Kazemi",      "Fereshteh",  "Kazemi"],
    ["Fida Qasemi",           "Fida",       "Qasemi"],
    ["Forough Farrokhzad",    "Forough",    "Farrokhzad"],
    ["Fozia Koofi",           "Fozia",      "Koofi"],
    ["Freshta Karim",         "Freshta",    "Karim"],
    ["Geeti Pasha",           "Geeti",      "Pasha"],
    ["Gelareh Abbasi",        "Gelareh",    "Abbasi"],
    ["Ghadir Mounib",         "Ghadir",     "Mounib"],
    ["Golshifteh Farahani",   "Golshifteh", "Farahani"],
    ["Habiba Sarabi",         "Habiba",     "Sarabi"],
    ["Hadia Tajik",           "Hadia",      "Tajik"],
    ["Hafsa Zayyan",          "Hafsa",      "Zayyan"],
    ["Haifa Wehbe",           "Haifa",      "Wehbe"],
    ["Hala Gorani",           "Hala",       "Gorani"],
    ["Hamida Barmaki",        "Hamida",     "Barmaki"],
    ["Hangama Zohra",         "Hangama",    "Zohra"],
    ["Hania Amir",            "Hania",      "Amir"],
    ["Hasina Safi",           "Hasina",     "Safi"],
    ["Hawa Alam",             "Hawa",       "Alam"],
    ["Hayat Mirshad",         "Hayat",      "Mirshad"],
    ["Hediyeh Tehrani",       "Hediyeh",    "Tehrani"],
    ["Hina Rabbani",          "Hina",       "Rabbani"],
    ["Hind Rostom",           "Hind",       "Rostom"],
    ["Homa Darabi",           "Homa",       "Darabi"],
    ["Homira Qaderi",         "Homira",     "Qaderi"],
    ["Huda Kattan",           "Huda",       "Kattan"],
    ["Iman Abdulmajid",       "Iman",       "Abdulmajid"],
    ["Kamila Sidiqi",         "Kamila",     "Sidiqi"],
    ["Kawsar Sharifi",        "Kawsar",     "Sharifi"],
    ["Khadija Bashir",        "Khadija",    "Bashir"],
    ["Laila Freivalds",       "Laila",      "Freivalds"],
    ["Laila Haidari",         "Laila",      "Haidari"],
    ["Layla Murad",           "Layla",      "Murad"],
    ["Leena Alam",            "Leena",      "Alam"],
    ["Leila Hatami",          "Leila",      "Hatami"],
    ["Lima Azimi",            "Lima",       "Azimi"],
    ["Lina Ben Mhenni",       "Lina",       "Ben Mhenni"],
    ["Mahbouba Seraj",        "Mahbouba",   "Seraj"],
    ["Mahira Khan",           "Mahira",     "Khan"],
    ["Manal al-Sharif",       "Manal",      "al-Sharif"],
    ["Mariam Durrani",        "Mariam",     "Durrani"],
    ["Mariam Ghani",          "Mariam",     "Ghani"],
    ["Marjane Satrapi",       "Marjane",    "Satrapi"],
    ["Marwa Elselehdar",      "Marwa",      "Elselehdar"],
    ["Maryam Monsef",         "Maryam",     "Monsef"],
    ["Massouda Jalal",        "Massouda",   "Jalal"],
    ["Meena Keshwar",         "Meena",      "Keshwar"],
    ["Mehrnaz Dabir",         "Mehrnaz",    "Dabir"],
    ["Mina Mangal",           "Mina",       "Mangal"],
    ["Mitra Hajjar",          "Mitra",      "Hajjar"],
    ["Mona Zaki",             "Mona",       "Zaki"],
    ["Mozhdah Jamalzadah",    "Mozhdah",    "Jamalzadah"],
    ["Muna Wassef",           "Muna",       "Wassef"],
    ["Muniba Mazari",         "Muniba",     "Mazari"],
    ["Nadia Anjuman",         "Nadia",      "Anjuman"],
    ["Naghma Shaperai",       "Naghma",     "Shaperai"],
    ["Nahid Persson",         "Nahid",      "Persson"],
    ["Nargis Fakhri",         "Nargis",     "Fakhri"],
    ["Nargis Nehan",          "Nargis",     "Nehan"],
    ["Nasrin Sotoudeh",       "Nasrin",     "Sotoudeh"],
    ["Nawal El Saadawi",      "Nawal",      "El Saadawi"],
    ["Nelofer Pazira",        "Nelofer",    "Pazira"],
    ["Niki Karimi",           "Niki",       "Karimi"],
    ["Niloufar Ardalan",      "Niloufar",   "Ardalan"],
    ["Niloufar Bayat",        "Niloufar",   "Bayat"],
    ["Noor Jahan",            "Noor",       "Jahan"],
    ["Palwasha Hassan",       "Palwasha",   "Hassan"],
    ["Parvin Etesami",        "Parvin",     "Etesami"],
    ["Parwana Amiri",         "Parwana",    "Amiri"],
    ["Qamar Gul",             "Qamar",      "Gul"],
    ["Rabea Balkhi",          "Rabea",      "Balkhi"],
    ["Rahima Jami",           "Rahima",     "Jami"],
    ["Rania Al-Abdullah",     "Rania",      "Al-Abdullah"],
    ["Reem Abdullah",         "Reem",       "Abdullah"],
    ["Rola Ghani",            "Rola",       "Ghani"],
    ["Roxana Saberi",         "Roxana",     "Saberi"],
    ["Roya Mahboob",          "Roya",       "Mahboob"],
    ["Saba Qamar",            "Saba",       "Qamar"],
    ["Sahraa Karimi",         "Sahraa",     "Karimi"],
    ["Sajal Aly",             "Sajal",      "Aly"],
    ["Salma Zadeh",           "Salma",      "Zadeh"],
    ["Samira Makhmalbaf",     "Samira",     "Makhmalbaf"],
    ["Sanam Baloch",          "Sanam",      "Baloch"],
    ["Sarah Shahi",           "Sarah",      "Shahi"],
    ["Seeta Qasemi",          "Seeta",      "Qasemi"],
    ["Shabana Azmi",          "Shabana",    "Azmi"],
    ["Shaharzad Akbar",       "Shaharzad",  "Akbar"],
    ["Shirin Ebadi",          "Shirin",     "Ebadi"],
    ["Shukria Barakzai",      "Shukria",    "Barakzai"],
    ["Soheila Siddiq",        "Soheila",    "Siddiq"],
    ["Soraya Tarzi",          "Soraya",     "Tarzi"],
    ["Tahmina Alvi",          "Tahmina",    "Alvi"],
    ["Tahmineh Milani",       "Tahmineh",   "Milani"],
    ["Taraneh Alidoosti",     "Taraneh",    "Alidoosti"],
    ["Vida Samadzai",         "Vida",       "Samadzai"],
    ["Wazhma Frogh",          "Wazhma",     "Frogh"],
    ["Yalda Hakim",           "Yalda",      "Hakim"],
    ["Yasmin Levy",           "Yasmin",     "Levy"],
    ["Zainab Salbi",          "Zainab",     "Salbi"],
    ["Zara Kayani",           "Zara",       "Kayani"],
    ["Zarghona Walid",        "Zarghona",   "Walid"],
    ["Zarifa Ghafari",        "Zarifa",     "Ghafari"],
    ["Zohra Karimi",          "Zohra",      "Karimi"]
];

publicVariable "MISSION_CivilianNames_Male";
publicVariable "MISSION_CivilianNames_Female";

// ============================================================
// === POOLS D'ACTIFS VISUELS
// ============================================================

// Visages masculins perses/takistanais
MISSION_CivilianMaleFaces = [
    "PersianHead_A3_01", "PersianHead_A3_02", "PersianHead_A3_03",
    "GreekHead_A3_01",   "GreekHead_A3_02",   "GreekHead_A3_03",
    "GreekHead_A3_04",   "GreekHead_A3_05",   "GreekHead_A3_06"
];

// Couvre-chefs masculins CUP Takistan
MISSION_CivilianHats = [
    "CUP_H_TKI_Lungee_Open_01", "CUP_H_TKI_Lungee_Open_02", "CUP_H_TKI_Lungee_Open_03",
    "CUP_H_TKI_Lungee_Open_04", "CUP_H_TKI_Lungee_Open_05", "CUP_H_TKI_Lungee_Open_06",
    "CUP_H_TKI_Pakol_1_01",     "CUP_H_TKI_Pakol_1_02",     "CUP_H_TKI_Pakol_1_03",
    "CUP_H_TKI_Pakol_1_04",     "CUP_H_TKI_Pakol_1_05",
    "CUP_H_TKI_SkullCap_01",    "CUP_H_TKI_SkullCap_02",    "CUP_H_TKI_SkullCap_03",
    "CUP_H_TKI_SkullCap_04",    "CUP_H_TKI_SkullCap_05",    "CUP_H_TKI_SkullCap_06"
];

// Barbes masculines CUP (slot lunettes)
MISSION_CivilianBeards = ["CUP_Beard_Brown", "CUP_Beard_Black"];

// Armes disponibles pour les bandits OPFOR / Indépendants
// Format : [arme_pri, mag_pri, nb_pri, arme_sec, mag_sec, nb_sec, fumigène, nb_fumi, soin, nb_soin]
MISSION_BanditLoadouts = [
    ["arifle_TRG20_F",          "30Rnd_556x45_Stanag",       7, "hgun_Rook40_F",            "16Rnd_9x21_Mag",        5, "SmokeShell", 2, "FirstAidKit", 2],
    ["hgun_PDW2000_F",          "30Rnd_9x21_Mag",            7, "hgun_P07_F",               "16Rnd_9x21_Mag",        5, "SmokeShell", 2, "FirstAidKit", 2],
    ["SMG_02_F",                "30Rnd_9x21_Mag",            7, "hgun_Rook40_F",            "16Rnd_9x21_Mag",        5, "SmokeShell", 2, "FirstAidKit", 2],
    ["arifle_Mk20C_F",          "30Rnd_556x45_Stanag",       6, "hgun_Pistol_heavy_02_F",   "6Rnd_45ACP_Cylinder",   6, "SmokeShell", 2, "FirstAidKit", 2],
    ["SMG_01_F",                "30Rnd_45ACP_Mag_SMG_01",    7, "hgun_ACPC2_F",             "9Rnd_45ACP_Mag",        5, "SmokeShell", 2, "FirstAidKit", 2],
    ["arifle_Mk20_F",           "30Rnd_556x45_Stanag",       7, "hgun_ACPC2_F",             "9Rnd_45ACP_Mag",        5, "SmokeShell", 2, "FirstAidKit", 2],
    ["arifle_TRG21_F",          "30Rnd_556x45_Stanag",       7, "hgun_Pistol_heavy_01_F",   "11Rnd_45ACP_Mag",       5, "SmokeShell", 2, "FirstAidKit", 2],
    ["arifle_Katiba_C_F",       "30Rnd_65x39_caseless_green",6, "hgun_Pistol_heavy_02_F",   "6Rnd_45ACP_Cylinder",   5, "SmokeShell", 2, "FirstAidKit", 2],
    ["arifle_AKM_F",            "30Rnd_762x39_Mag_F",        9, "hgun_Rook40_F",            "16Rnd_9x21_Mag",        5, "SmokeShell", 2, "FirstAidKit", 2],
    ["arifle_AKS_F",            "30Rnd_545x39_Mag_F",        9, "hgun_Pistol_heavy_02_F",   "6Rnd_45ACP_Cylinder",   5, "SmokeShell", 2, "FirstAidKit", 2],
    ["srifle_DMR_06_camo_F",    "20Rnd_762x51_Mag",          8, "hgun_Rook40_F",            "16Rnd_9x21_Mag",        5, "SmokeShell", 2, "FirstAidKit", 2],
    ["sgun_HunterShotgun_01_F", "2Rnd_12Gauge_Pellets",     13, "hgun_P07_F",               "16Rnd_9x21_Mag",        5, "SmokeShell", 2, "FirstAidKit", 2],
    ["LMG_03_F",                "200Rnd_556x45_Box_F",       5, "hgun_Pistol_heavy_01_F",   "11Rnd_45ACP_Mag",       5, "SmokeShell", 2, "FirstAidKit", 2],
    ["srifle_DMR_01_F",         "10Rnd_762x54_Mag",          9, "hgun_P07_F",               "16Rnd_9x21_Mag",        5, "SmokeShell", 2, "FirstAidKit", 2]
];

// Sacs à dos disponibles pour les bandits
MISSION_BanditBackpacks = [
    "b_Kitbag_cbr",         "b_Kitbag_rgr",         "b_Kitbag_sgg",
    "CUP_B_TK_Medic_Desert","B_Messenger_Black_F",  "B_Messenger_Coyote_F",
    "B_Messenger_Grey_F",   "B_Messenger_Olive_F",  "B_TacticalPack_blk",
    "B_TacticalPack_ocamo", "CUP_B_RUS_Backpack"
];

publicVariable "MISSION_CivilianMaleFaces";
publicVariable "MISSION_CivilianHats";
publicVariable "MISSION_CivilianBeards";
// MISSION_BanditLoadouts et MISSION_BanditBackpacks restent serveur-local (non publicVariable)

// ============================================================
// === COLLECTE DES TEMPLATES DEPUIS L'ÉDITEUR
// ============================================================

MISSION_CivilianTemplates = [];
private _toDelete = [];

{
    private _varName = vehicleVarName _x;

    private _lv = toLower _varName;
    if (
        (_lv find "template_" == 0) ||
        (_lv find "max_tak_woman" == 0) ||
        (_lv find "max_taky_woman" == 0) ||
        (_lv find "max_tak2_woman" == 0)
    ) then {
        private _class    = typeOf _x;
        private _loadout  = getUnitLoadout _x;

        // Détection du genre : les femmes (mod Max_Tak) ont "woman" dans leur nom de classe
        private _isFemale = "woman" in (toLower _class);

        // Visage : femmes → défaut du modèle (chaîne vide), hommes → perse aléatoire
        private _face  = if (_isFemale) then { "" } else { selectRandom MISSION_CivilianMaleFaces };

        // Pitch : femmes → voix pitchée haute, hommes → pitch neutre
        private _pitch = if (_isFemale) then { selectRandom [1.3, 1.4] } else { 1.0 };

        // Masquer et désactiver la simulation immédiatement pour éliminer le pop visuel sur les clients
        _x hideObjectGlobal true;
        _x enableSimulationGlobal false;

        // Format stocké : [classe, chargement, estFemme, visage, pitch]
        MISSION_CivilianTemplates pushBack [_class, _loadout, _isFemale, _face, _pitch];
        _toDelete pushBack _x;

        if (DEBUG_MODE) then {
            diag_log format [
                "[LL][initCivilians] template collecté : '%1' | classe : %2 | genre : %3 | visage : %4 | pitch : %5",
                _varName, _class,
                if (_isFemale) then {"F"} else {"M"},
                _face, _pitch
            ];
        };
    };
} forEach (allMissionObjects "Man");

// Suppression APRÈS collecte complète pour éviter les effets de bord sur l'itération
{ deleteVehicle _x; } forEach _toDelete;

publicVariable "MISSION_CivilianTemplates";

if (DEBUG_MODE) then {
    diag_log format [
        "[LL][initCivilians] %1 template(s) collecté(s) et supprimé(s).",
        count MISSION_CivilianTemplates
    ];
};

// ============================================================
// === SUPPRESSION DE SÉCURITÉ (Max_Tak women + CUP civilians résiduels)
// ============================================================
// Passe de filet : supprime toute unité civile/mod non-joueur qui n'aurait pas
// été retirée lors de la collecte, pour éviter les doublons visuels.

{
    private _lc = toLower typeOf _x;
    private _lv = toLower vehicleVarName _x;

    if (
        (_lv find "template_"      == 0) ||
        (_lv find "max_tak_woman"  == 0) ||
        (_lv find "max_taky_woman" == 0) ||
        (_lv find "max_tak2_woman" == 0) ||
        (_lc find "max_tak"        >= 0) ||
        (_lc find "max_taky"       >= 0) ||
        (_lc find "cup_c_tk_"      >= 0)
    ) then {
        _x hideObjectGlobal true;
        _x enableSimulationGlobal false;
        deleteVehicle _x;
    };
} forEach (allMissionObjects "Man");

// ============================================================
// === APPLICATION AUX UNITÉS EXISTANTES + GESTIONNAIRE SPAWNS FUTURS
// ============================================================

[] spawn {
    // Cède le frame courant pour s'assurer que tous les deleteVehicle sont traités
    sleep 0;

    // Application aux unités non-Indépendantes déjà présentes (civils, OPFOR, BLUFOR)
    {
        [_x] call LL_fnc_applyCivilianTemplate;
    } forEach (allUnits select { !isNull _x && alive _x && !isPlayer _x && side _x != independent && side _x != resistance });

    // Gestionnaire pour les unités spawnées ultérieurement
    addMissionEventHandler ["EntityCreated", {
        params ["_entity"];
        if (isNull _entity || !(_entity isKindOf "CAManBase")) exitWith {};

        // Délai court : laisse le moteur initialiser la locality et le chargement tout en limitant le pop visuel
        [_entity] spawn {
            params ["_entity"];
            sleep 0.05;
            if (isNull _entity || !alive _entity || isPlayer _entity) exitWith {};
            [_entity] call LL_fnc_applyCivilianTemplate;
        };
    }];

    if (DEBUG_MODE) then {
        diag_log "[LL][initCivilians] Initialisation terminée. EntityCreated actif.";
    };
};

true

class DelhiLocation {
  final String name;
  final String area;
  final String category;
  final double lat;
  final double lng;

  const DelhiLocation({
    required this.name,
    required this.area,
    required this.category,
    required this.lat,
    required this.lng,
  });
}

const List<DelhiLocation> delhiLocations = [
  // Major Central & North Delhi Landmarks
  DelhiLocation(name: 'Connaught Place, New Delhi', area: 'Central Delhi', category: 'Commercial Hub', lat: 28.6315, lng: 77.2167),
  DelhiLocation(name: 'India Gate, New Delhi', area: 'Central Delhi', category: 'Monument', lat: 28.6129, lng: 77.2295),
  DelhiLocation(name: 'ITO, New Delhi', area: 'Central Delhi', category: 'Institutional / Transit', lat: 28.6282, lng: 77.2410),
  DelhiLocation(name: 'Red Fort (Lal Qila), Old Delhi', area: 'Central Delhi', category: 'Heritage', lat: 28.6562, lng: 77.2410),
  DelhiLocation(name: 'Chandni Chowk, Old Delhi', area: 'North Delhi', category: 'Commercial Hub', lat: 28.6506, lng: 77.2303),
  DelhiLocation(name: 'Kashmere Gate ISBT, Delhi', area: 'North Delhi', category: 'Bus Terminal / Transit', lat: 28.6675, lng: 77.2285),
  DelhiLocation(name: 'North Campus, Delhi University (DU)', area: 'North Delhi', category: 'University', lat: 28.6880, lng: 77.2092),
  DelhiLocation(name: 'Karol Bagh, New Delhi', area: 'Central-West Delhi', category: 'Commercial & Residential', lat: 28.6514, lng: 77.1907),
  DelhiLocation(name: 'Rajendra Place, New Delhi', area: 'Central Delhi', category: 'Commercial Hub', lat: 28.6432, lng: 77.1788),
  DelhiLocation(name: 'Civil Lines, Delhi', area: 'North Delhi', category: 'Residential', lat: 28.6814, lng: 77.2227),
  DelhiLocation(name: 'Alipur, Delhi', area: 'North Delhi', category: 'Suburban', lat: 28.7973, lng: 77.1387),
  DelhiLocation(name: 'Bawana, Delhi', area: 'North-West Delhi', category: 'Industrial Area', lat: 28.7997, lng: 77.0329),
  DelhiLocation(name: 'Narela, Delhi', area: 'North Delhi', category: 'Suburban', lat: 28.8465, lng: 77.0857),
  DelhiLocation(name: 'Burari Crossing, Delhi', area: 'North Delhi', category: 'Transit', lat: 28.7286, lng: 77.1993),
  DelhiLocation(name: 'Rohini Sector 10, Delhi', area: 'North-West Delhi', category: 'Residential & Hub', lat: 28.7159, lng: 77.1130),
  DelhiLocation(name: 'Pitampura (TV Tower), Delhi', area: 'North-West Delhi', category: 'Commercial & Residential', lat: 28.6989, lng: 77.1384),
  DelhiLocation(name: 'Ashok Vihar, Delhi', area: 'North-West Delhi', category: 'Residential', lat: 28.6885, lng: 77.1739),
  DelhiLocation(name: 'Jahangirpuri, Delhi', area: 'North Delhi', category: 'Transit & Residential', lat: 28.7260, lng: 77.1627),

  // South & South-East Delhi
  DelhiLocation(name: 'Hauz Khas, New Delhi', area: 'South Delhi', category: 'Cultural & Dining', lat: 28.5494, lng: 77.2001),
  DelhiLocation(name: 'Saket (Select Citywalk), New Delhi', area: 'South Delhi', category: 'Commercial & Mall', lat: 28.5284, lng: 77.2185),
  DelhiLocation(name: 'Nehru Place, New Delhi', area: 'South Delhi', category: 'IT & Commercial Hub', lat: 28.5492, lng: 77.2529),
  DelhiLocation(name: 'Lajpat Nagar (Central Market), New Delhi', area: 'South Delhi', category: 'Market & Residential', lat: 28.5685, lng: 77.2433),
  DelhiLocation(name: 'Nehru Nagar, New Delhi', area: 'South Delhi', category: 'Residential', lat: 28.5685, lng: 77.2514),
  DelhiLocation(name: 'AIIMS & Safdarjung Hospital, New Delhi', area: 'South Delhi', category: 'Medical Hub', lat: 28.5672, lng: 77.2100),
  DelhiLocation(name: 'Lodhi Garden / Lodhi Road, New Delhi', area: 'South Delhi', category: 'Heritage & Park', lat: 28.5926, lng: 77.2393),
  DelhiLocation(name: 'Jawaharlal Nehru Stadium (JLN), Delhi', area: 'South Delhi', category: 'Sports Complex', lat: 28.5834, lng: 77.2335),
  DelhiLocation(name: 'Okhla Phase-2 / Industrial Area, Delhi', area: 'South-East Delhi', category: 'Industrial & Tech', lat: 28.5375, lng: 77.2779),
  DelhiLocation(name: 'CRRI Mathura Road, Delhi', area: 'South-East Delhi', category: 'Highway & Research', lat: 28.5501, lng: 77.2752),
  DelhiLocation(name: 'Vasant Kunj, New Delhi', area: 'South-West Delhi', category: 'Residential & Malls', lat: 28.5244, lng: 77.1558),
  DelhiLocation(name: 'Aya Nagar, New Delhi', area: 'South Delhi (Border)', category: 'Suburban', lat: 28.4765, lng: 77.1329),
  DelhiLocation(name: 'Qutub Minar, Mehrauli', area: 'South Delhi', category: 'Heritage', lat: 28.5245, lng: 77.1855),
  DelhiLocation(name: 'Lotus Temple, Kalkaji, New Delhi', area: 'South Delhi', category: 'Landmark', lat: 28.5535, lng: 77.2588),

  // West & South-West Delhi (Airport, Dwarka)
  DelhiLocation(name: 'Indira Gandhi International Airport (T3), Delhi', area: 'South-West Delhi', category: 'Airport Terminal', lat: 28.5562, lng: 77.1000),
  DelhiLocation(name: 'Aerocity, New Delhi', area: 'South-West Delhi', category: 'Hospitality & Commercial', lat: 28.5495, lng: 77.1215),
  DelhiLocation(name: 'Dwarka Sector 8, New Delhi', area: 'South-West Delhi', category: 'Residential', lat: 28.5656, lng: 77.0670),
  DelhiLocation(name: 'Dwarka Sector 21 (Metro Interchange), Delhi', area: 'South-West Delhi', category: 'Transit Hub', lat: 28.5523, lng: 77.0583),
  DelhiLocation(name: 'NSIT Dwarka, Sector 3, Delhi', area: 'South-West Delhi', category: 'University', lat: 28.6105, lng: 77.0355),
  DelhiLocation(name: 'Janakpuri District Centre, New Delhi', area: 'West Delhi', category: 'Commercial Hub', lat: 28.6297, lng: 77.0818),
  DelhiLocation(name: 'Punjabi Bagh, New Delhi', area: 'West Delhi', category: 'Residential & Commercial', lat: 28.6730, lng: 77.1461),
  DelhiLocation(name: 'Rajouri Garden, New Delhi', area: 'West Delhi', category: 'Commercial & Malls', lat: 28.6477, lng: 77.1207),
  DelhiLocation(name: 'Mundka, West Delhi', area: 'West Delhi', category: 'Industrial & Metro', lat: 28.6824, lng: 77.0306),
  DelhiLocation(name: 'Najafgarh, Delhi', area: 'South-West Delhi', category: 'Suburban Hub', lat: 28.6095, lng: 76.9812),

  // East Delhi & Trans-Yamuna
  DelhiLocation(name: 'Anand Vihar ISBT & Railway Station, Delhi', area: 'East Delhi', category: 'Transit Hub', lat: 28.6466, lng: 77.3155),
  DelhiLocation(name: 'Patparganj Industrial Area, Delhi', area: 'East Delhi', category: 'Commercial & Industrial', lat: 28.6116, lng: 77.2906),
  DelhiLocation(name: 'Mayur Vihar Phase 1, Delhi', area: 'East Delhi', category: 'Residential', lat: 28.6083, lng: 77.2954),
  DelhiLocation(name: 'Laxmi Nagar, East Delhi', area: 'East Delhi', category: 'Commercial Hub', lat: 28.6304, lng: 77.2773),
  DelhiLocation(name: 'East Arjun Nagar, Delhi', area: 'East Delhi', category: 'Residential', lat: 28.6570, lng: 77.2947),
  DelhiLocation(name: 'IHBAS, Dilshad Garden, Delhi', area: 'East Delhi', category: 'Medical Hub', lat: 28.6827, lng: 77.3049),
  DelhiLocation(name: 'Akshardham Temple, Delhi', area: 'East Delhi', category: 'Heritage', lat: 28.6127, lng: 77.2773),

  // NCR Extensions (Gurugram, Noida, Faridabad, Ghaziabad)
  DelhiLocation(name: 'DLF Cyber City, Gurugram', area: 'NCR Gurugram', category: 'Corporate Hub', lat: 28.4952, lng: 77.0890),
  DelhiLocation(name: 'Golf Course Road, Gurugram', area: 'NCR Gurugram', category: 'Corporate & Residential', lat: 28.4595, lng: 77.0980),
  DelhiLocation(name: 'IFFCO Chowk, Gurugram', area: 'NCR Gurugram', category: 'Transit & Commercial', lat: 28.4720, lng: 77.0694),
  DelhiLocation(name: 'Noida Sector 18 (Atta Market)', area: 'NCR Noida', category: 'Commercial & Malls', lat: 28.5700, lng: 77.3200),
  DelhiLocation(name: 'Noida Sector 62 (Electronic City)', area: 'NCR Noida', category: 'IT Hub & Institutional', lat: 28.6280, lng: 77.3670),
  DelhiLocation(name: 'Noida City Centre (Sector 32)', area: 'NCR Noida', category: 'Transit & Residential', lat: 28.5747, lng: 77.3560),
  DelhiLocation(name: 'Kaushambi / Vaishali, Ghaziabad', area: 'NCR Ghaziabad', category: 'Transit & Residential', lat: 28.6430, lng: 77.3270),
];

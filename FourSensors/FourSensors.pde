// define spi bus pins
#define SLAVESELECT 10
#define SPICLOCK 13
#define DATAOUT 11	//MOSI
#define DATAIN 12	 //MISO
#define UBLB(a,b)  ( ( (a) << 8) | (b) )
#define UBLB19(a,b) ( ( (a) << 16 ) | (b) )

//Addresses
#define REVID 0x00	//ASIC Revision Number
#define OPSTATUS 0x04   //Operation Status
#define STATUS 0x07     //ASIC Status
#define START 0x0A      //Constant Readings
#define PRESSURE 0x1F   //Pressure 3 MSB
#define PRESSURE_LSB 0x20 //Pressure 16 LSB
#define TEMP 0x21       //16 bit temp
char rev_in_byte;	    
int temp_in;
unsigned long pressure_lsb;
unsigned long pressure_msb;
unsigned long temp_pressure;
unsigned long pressure;

//DEFINES for Temperature/Humidity
#define SHT15_DATA  4
#define SHT15_CLOCK 5
#define SHT15_CMD_TEMP 0b00000011
#define SHT15_CMD_HUMIDITY 0b00000101
int val;
int temp;
int humid;

// TEMT6000
#define TEMT6000_PIN 0
int light;

void setup()
{
  byte clr;
  pinMode(DATAOUT, OUTPUT);
  pinMode(DATAIN, INPUT);
  pinMode(SPICLOCK,OUTPUT);
  pinMode(SLAVESELECT,OUTPUT);
  digitalWrite(SLAVESELECT,HIGH); //disable device  
  
  SPCR = B01010011; //MPIE=0, SPE=1 (on), DORD=0 (MSB first), MSTR=1 (master), CPOL=0 (clock idle when low), CPHA=0 (samples MOSI on rising edge), SPR1=0 & SPR0=0 (500kHz)
  clr=SPSR;
  clr=SPDR;
  delay(10);
  Serial.begin(9600);
  delay(500);

  write_register(0x03,0x09);
}

void loop()
{
  rev_in_byte = read_register(REVID);
  
  pressure_msb = read_register(PRESSURE);
  pressure_msb &= B00000111;
  pressure_lsb = read_register16(PRESSURE_LSB);
  pressure_lsb &= 0x0000FFFF;
  pressure = UBLB19(pressure_msb, pressure_lsb);
  pressure /= 400;
    
//  temp_in = read_register16(TEMP);
//  temp_in = temp_in / 20;
//  temp_in = ((1.8) *temp_in) + 32;
//  Serial.print("TEMP F [");
//  Serial.print(temp_in , DEC);
//  Serial.println("]");

  sendCommandSHT(SHT15_CMD_TEMP, SHT15_DATA, SHT15_CLOCK);
  waitForResultSHT(SHT15_DATA);
  val = getData16SHT(SHT15_DATA, SHT15_CLOCK);
  skipCrcSHT(SHT15_DATA, SHT15_CLOCK);

  temp = -40.0 + 0.018 * (float)val;

  sendCommandSHT(SHT15_CMD_HUMIDITY, SHT15_DATA, SHT15_CLOCK);
  waitForResultSHT(SHT15_DATA);
  val = getData16SHT(SHT15_DATA, SHT15_CLOCK);
  skipCrcSHT(SHT15_DATA, SHT15_CLOCK);
  humid = -4.0 + 0.0405 * val + -0.0000028 * val * val;

  light = analogRead(TEMT6000_PIN);

  Serial.print("Temp:");
  Serial.println(temp, DEC);
  Serial.print("Humidity:");
  Serial.println(humid, DEC);
  Serial.print("Pressure:");
  Serial.println(pressure, DEC);
  Serial.print("Light:");
  Serial.println(light, DEC);
  
  delay(2500);
}

char spi_transfer(volatile char data)
{
  SPDR = data;			  // Start the transmission
  while (!(SPSR & (1<<SPIF)))     // Wait for the end of the transmission
  {
  };
  return SPDR;			  // return the received byte
}

char read_register(char register_name)
{
    char in_byte;
    register_name <<= 2;
    register_name &= B11111100; //Read command
  
    digitalWrite(SLAVESELECT,LOW); //Select SPI Device
    spi_transfer(register_name); //Write byte to device
    in_byte = spi_transfer(0x00); //Send nothing, but we should get back the register value
    digitalWrite(SLAVESELECT,HIGH);
    delay(10);
    return(in_byte);
  
}

float read_register16(char register_name)
{
    byte in_byte1;
    byte in_byte2;
    float in_word;

    register_name <<= 2;
    register_name &= B11111100; //Read command

    digitalWrite(SLAVESELECT,LOW); //Select SPI Device
    spi_transfer(register_name); //Write byte to device
    in_byte1 = spi_transfer(0x00);
    in_byte2 = spi_transfer(0x00);
    digitalWrite(SLAVESELECT,HIGH);
    in_word = UBLB(in_byte1,in_byte2);
    return(in_word);
}


void write_register(char register_name, char register_value)
{
    register_name <<= 2;
    register_name |= B00000010; //Write command

    digitalWrite(SLAVESELECT,LOW); //Select SPI device
    spi_transfer(register_name); //Send register location
    spi_transfer(register_value); //Send value to record into register
    digitalWrite(SLAVESELECT,HIGH);
} 

int shiftIn(int dataPin, int clockPin, int numBits)
{
   int ret = 0;
   int i;

   for (i=0; i<numBits; ++i)
   {
      digitalWrite(clockPin, HIGH);
      delay(10);  // I don't know why I need this, but without it I don't get my 8 lsb of temp
      ret = ret*2 + digitalRead(dataPin);
      digitalWrite(clockPin, LOW);
   }

   return(ret);
}

void sendCommandSHT(int command, int dataPin, int clockPin)
{
  int ack;

  // Transmission Start
  pinMode(dataPin, OUTPUT);
  pinMode(clockPin, OUTPUT);
  digitalWrite(dataPin, HIGH);
  digitalWrite(clockPin, HIGH);
  digitalWrite(dataPin, LOW);
  digitalWrite(clockPin, LOW);
  digitalWrite(clockPin, HIGH);
  digitalWrite(dataPin, HIGH);
  digitalWrite(clockPin, LOW);
           
  // The command (3 msb are address and must be 000, and last 5 bits are command)
  shiftOut(dataPin, clockPin, MSBFIRST, command);

  // Verify we get the coorect ack
  digitalWrite(clockPin, HIGH);
  pinMode(dataPin, INPUT);
  ack = digitalRead(dataPin);
  if (ack != LOW)
    Serial.println("Ack Error 0");
  digitalWrite(clockPin, LOW);
  ack = digitalRead(dataPin);
  if (ack != HIGH)
     Serial.println("Ack Error 1");
}

void waitForResultSHT(int dataPin)
{
  int i;
  int ack;
  
  pinMode(dataPin, INPUT);
  
  for(i= 0; i < 100; ++i)
  {
    delay(10);
    ack = digitalRead(dataPin);

    if (ack == LOW)
      break;
  }
  
  if (ack == HIGH)
    Serial.println("Ack Error 2");
}

int getData16SHT(int dataPin, int clockPin)
{
  int val;
  
  // Get the most significant bits
  pinMode(dataPin, INPUT);
  pinMode(clockPin, OUTPUT);
  val = shiftIn(dataPin, clockPin, 8);
  val *= 256;

  // Send the required ack
  pinMode(dataPin, OUTPUT);
  digitalWrite(dataPin, HIGH);
  digitalWrite(dataPin, LOW);
  digitalWrite(clockPin, HIGH);
  digitalWrite(clockPin, LOW);
           
  // Get the lest significant bits
  pinMode(dataPin, INPUT);
  val |= shiftIn(dataPin, clockPin, 8);

  return val;
}

void skipCrcSHT(int dataPin, int clockPin)
{
  // Skip acknowledge to end trans (no CRC)
  pinMode(dataPin, OUTPUT);
  pinMode(clockPin, OUTPUT);

  digitalWrite(dataPin, HIGH);
  digitalWrite(clockPin, HIGH);
  digitalWrite(clockPin, LOW);
}

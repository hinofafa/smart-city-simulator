package entities;

public class BusStop {

	private String name;
	private int numPassanger;
	private float lat;
	private float lon;
	
	public String getName() {
		return name;
	}
	public void setName(String name) {
		this.name = name;
	}
	public float getLat() {
		return lat;
	}
	public void setLat(float lat) {
		this.lat = lat;
	}
	public float getLon() {
		return lon;
	}
	public void setLon(float lon) {
		this.lon = lon;
	}
	public int getNumPassanger() {
		return numPassanger;
	}
	public void setNumPassanger(int numPassanger) {
		this.numPassanger = numPassanger;
	}
	
}

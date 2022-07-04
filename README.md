# sunst0rm
iOS Tether Downgrader

## how to use?
### Restoring
python3 restore.py -i ipsw.ipsw -t shsh.shsh2 -r true -d DEVICEBOARD ( use --kpp true if you have kpp, otherwise dont add --kpp )

### booting
python3 restore.py -i ipsw.ipsw -t shsh.shsh2 -b true -d DEVICEBOARD ( use --kpp true if you have kpp, otherwise dont add --kpp ) -id IDENTIFIER
./boot.sh
